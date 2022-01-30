# -*- coding: utf-8 -*-
#"""NLP Intelligent systems.ipynb
#
#Automatically generated by Colaboratory.

#Original file is located at
#    https://colab.research.google.com/drive/1gmn75RbClhwy8TX5tbPxaFCFpO9Lv7Wn
#
#**Instalamos las librerias y cargamos los datos del dataset**
#"""

install.packages("keras")
install.packages("quanteda")
install.packages("spacyr")
install.packages("reticulate")
install.packages("tokenizers.bpe")
install.packages("quanteda.textstats")
install.packages("quanteda.textplots")
install.packages("topicmodels")

#system2('sudo', 'apt-get install libgsl0-dev')
#install.packages("topicmodels")

library(keras)
library(utf8)
library(quanteda)
library(spacyr)
library(tokenizers.bpe)
library(quanteda.textstats)
library(ggplot2)
library(quanteda.textplots)
library(topicmodels)
library(tidyverse)

#"""Obtenemos los datos"""

eventosURL <- "https://raw.githubusercontent.com/alvaroame/NLPSimilarEvents/main/data/206974-0-agenda-eventos-culturales-100.csv"

#"""Leemos el archivo"""

data_events=read.csv(eventosURL,header=TRUE,sep=";", encoding = "ISO-8859-1")

data_events[1,]

lines <- readLines(eventosURL, encoding = "ISO-8859-1")

cabeceras <- lines[1]
linesQ <- lines[2:length(lines)]

#"""Verificamos el contenido del documento con las cabeceras y el primer evento"""

cabeceras

linesQ[1]

#"""Verificamos la codificación"""

linesQ[!utf8_valid(linesQ)]

linesQ_NFC <- utf8_normalize(linesQ)
sum(linesQ_NFC != linesQ)

#"""Creamos una regex para extraer el título"""

m <- regexec("^.*?;(.*?);.*?;.*?;.*?;.*?;.*?;.*?;.*?;.*?;(.*?);.*?;(.*?);.*", cabeceras)
m

#Extraemos del header
regmatches(cabeceras, m)

## Creamos una función con la expresión anterior
EVENT_PARTS <- function(x) {
  m <- regexec("^.*?;(.*?);.*?;.*?;.*?;.*?;.*?;.*?;.*?;.*?;(.*?);.*?;(.*?);.*", x)
  parts <- do.call(rbind,
                   lapply(regmatches(x, m), `[`, c(2L, 3L, 4L)))
  colnames(parts) <- c("TITULO", "DESCRIPCION", "ACTIVIDAD")
  parts
}

#probamos en titulos
EVENT_PARTS(cabeceras)

#probamos con un evento
EVENT_PARTS(linesQ[1])

#Modificamos la función para no obtener las comillas
EVENT_PARTS <- function(x) {
  m <- regexec("^.*?;\"(.*?)\";.*?\";.*?\";.*?\";.*?\";.*?\";.*?\";.*?\";.*?\";\"(.*?)\";.*?\";\"(.*?)\";.*", x)
  parts <- do.call(rbind,
                   lapply(regmatches(x, m), `[`, c(2L, 3L, 4L)))
  colnames(parts) <- c("TITULO", "DESCRIPCION", "ACTIVIDAD")
  parts
}

#probamos en titulos
EVENT_PARTS(linesQ[1])
EVENT_PARTS(linesQ[10])

#Se ve bien, lo hacemos para todos los demas
eventos <- EVENT_PARTS(linesQ[1:length(linesQ)])

#Eliminamos NA (Líneas sin información)
eventos <- na.omit(eventos)

eventos[1]
eventos[55]
eventos[length(eventos)]

#Revisamos los eventos
View(eventos)

#Hacemos limpieza de saltos de linea
eventswO <- gsub("[\n]{1,}", " ", eventos) #wo = without
eventswO[100]

#Hacemos limpieza de espacios
eventos <- gsub("[ ]{2,}", " ", eventswO) #We reassign the varible paragraphs
eventos[100]

#Utilizamos solamente el titulo de cada evento
titles <- eventos[,1]
View(titles)

#Creamos un modelo BPE con 500 eventos
model <- bpe(unlist(titles[1:500]))

#Aplicamos el modelo al evento 100
subtoks2 <- bpe_encode(model, x = unlist(titles[100]), type = "subwords")
head(unlist(subtoks2), n=20)

#Para obervsar el caracter correctamente
niceSubwords <- function(strings){
  gsub("\U2581", "_", strings)
}
niceSubwords(head(unlist(subtoks2), n=20))

#"""**CORPUS**

#La matriz TF-IDF nos permitirá calcular las distancias entre los titulos para poder identificar elementos duplicados o muy similares
#"""

texts_titles <- unlist(titles)
names(texts_titles) <- paste("T", 1:length(texts_titles)) #assigns a name to each string
corpus_titlesQ <- corpus(texts_titles)
docvars(corpus_titlesQ, field="T") <- 1:length(titles) #docvar with chapter number
corpus_titlesQ

#Variables asociadas al documento - T = Título, que se asignó en el paso anterior
head(docvars(corpus_titlesQ))

#Summary del CORPUS creado con los titulos de los eventos
summary(corpus_titlesQ)

#Graficamos Tokens por titulos
tokeninfo <- summary(corpus_titlesQ)
if (require(ggplot2))
  ggplot(data = tokeninfo, aes(x = T, y = Tokens, group = 1)) +
  geom_line() +
  geom_point() +
  scale_x_continuous(labels = c(seq(1789, 2017, 12)), breaks = seq(1789, 2017, 12)) +
  theme_bw()

#Sentences por titulos
if (require(ggplot2))
  ggplot(data = tokeninfo, aes(x = T, y = Sentences, group = 1)) +
  geom_line() +
  geom_point() +
  scale_x_continuous(labels = c(seq(1789, 2017, 12)), breaks = seq(1789, 2017, 12)) +
  theme_bw()

#Cuál es el título con más tokens
tokeninfo[which.max(tokeninfo$Tokens), ]

titles[1]

#Podemos buscar en nuestro conjunto de titulos por palabra
kwic(corpus_titlesQ, pattern = "vida")

kwic(corpus_titlesQ, pattern = "Lectura")

#Los Tokens del título 1
tokens(titles[1], remove_numbers = TRUE,  remove_punct = TRUE)

#Creamos el dfm (document-feature matrix) sin eliminar stopwords ni signos 
dfm_titlesQ <- dfm(tokens(corpus_titlesQ),
                   #Default values:
                   # tolower = TRUE #Convers to lowercase
                   # remove_padding = FALSE #Does padding (fills with blanks)
)

#Las palabras más frecuentes son:
topfeatures(dfm_titlesQ, 20) # 20 most frequent words

#Hay signos de puntuación y stopwords, podemos visualizar el wordcloud
set.seed(100)
textplot_wordcloud(dfm_titlesQ, min_freq = 6, random_order = FALSE,
                   rotation = .25,
                   colors = RColorBrewer::brewer.pal(12, "Dark2"))

#Ahora volvemos a crear el dfm (document-feature matrix), sin signos de puntuación
dfm_titlesQ_1 <- dfm(tokens(corpus_titlesQ,
                          remove_punct = TRUE))

#Las 20 palabras más frecuentes son:
topfeatures(dfm_titlesQ_1, 20) # 20 most frequent words

#Ahora eliminamos stopword del español
dfm_titlesQ_2 <- dfm_remove(dfm_titlesQ_1, stopwords("es"))

#Las 20 palabras más frecuentes son:
topfeatures(dfm_titlesQ_2, 10)

#Visualizamos el wordcloud
set.seed(100)
textplot_wordcloud(dfm_titlesQ_2, min_freq = 6, random_order = FALSE,
                   rotation = .25,
                   colors = RColorBrewer::brewer.pal(12, "Dark2"))

#"""**Similaridad en los títulos de los eventos**"""

tstat_cosine <- textstat_simil(dfm_titlesQ_2, method = "cosine", margin = "documents")
tstat_jaccard <- textstat_simil(dfm_titlesQ_2, method = "jaccard", margin = "documents")

tstat_cosine_df <- as.data.frame(tstat_cosine)
tstat_jaccard_df <- as.data.frame(tstat_jaccard)

#"""**Eventos duplicados**

#Consideramos eventos duplicados aquellos que su similaridad sea perfecta (1).
#"""

#duplicados using cosine  > 0.7
duplicados_cosine_7 <- tstat_cosine_df %>%
  filter(tstat_cosine_df$cosine > 0.7) %>%
  count(document1)
duplicados_cosine_7

#Titulo con más duplicados cosine > 0.7
duplicados_cosine_7[which.max(duplicados_cosine_7$n), ]

#Similares al evento 289
tstat_cosine_df[tstat_cosine_df$document1 == "T 289", ]

#Titulos 
titles[289]
titles[290]
titles[291]
titles[292]
titles[293]
titles[294]
titles[295]
titles[296]
titles[297]
titles[298]
titles[299]
titles[300]
titles[301]
titles[302]
titles[303]
titles[304]
titles[305]
titles[306]
titles[307]
titles[308]
titles[309]
titles[310]
titles[311]
titles[312]
titles[313]
titles[314]
titles[315]

#Plot de similarities del titulo 289
dotchart(as.list(tstat_cosine)$"T 289", xlab = "Titulo 289 cosine similarity")

#duplicados using jaccard > 0.7
duplicados_jaccard_7 <- tstat_jaccard_df %>%
  filter(tstat_jaccard_df$jaccard > 0.7) %>%
  count(document1)
duplicados_jaccard_7

#Titulo con más duplicados jaccard > 0.7
duplicados_jaccard_7[which.max(duplicados_jaccard_7$n), ]

#Similares al evento 296
tstat_jaccard_df[tstat_jaccard_df$document1 == "T 296", ]

#Titulos 
titles[296]
titles[297]
titles[298]
titles[299]
titles[300]
titles[301]
titles[302]
titles[303]
titles[304]
titles[305]
titles[306]

#Plot de similarities del titulo 296
dotchart(as.list(tstat_jaccard)$"T 296", xlab = "Titulo 296 jaccard similarity")

#duplicados using cosine perfect match
duplicados_cosine <- tstat_cosine_df %>%
  filter(tstat_cosine_df$cosine == 1) %>%
  count(document1)
duplicados_cosine

#duplicados using jaccard perfect match
duplicados_jaccard <- tstat_jaccard_df %>%
  filter(tstat_jaccard_df$jaccard == 1) %>%
  count(document1)
duplicados_jaccard

#Titulo con más duplicados cosine
duplicados_cosine[which.max(duplicados_cosine$n), ]

#Titulo con más duplicados jaccard
duplicados_jaccard[which.max(duplicados_jaccard$n), ]

#Plot de similarities del titulo 296
dotchart(as.list(tstat_cosine)$"T 296", xlab = "Titulo 296 cosine similarity")

#Plot de similarities del titulo 296
dotchart(as.list(tstat_jaccard)$"T 296", xlab = "Titulo 296 jaccard similarity")

#Cuales son los titulos con los que se encuentra duplicado el evento 296
titles[296]
titles[297]
titles[298]
titles[299]
titles[300]
titles[301]
titles[302]
titles[303]
titles[304]
titles[305]
titles[306]

#heap map cosine
tstat_cosine_df %>%
  filter(tstat_cosine_df$cosine >0.7) %>%
  ggplot(aes(x = document1, y = document2, fill = cosine)) + 
  geom_tile() + 
  scale_fill_gradient(low = "white", high = "steelblue")

#heap map jaccard
tstat_jaccard_df %>%
  filter(tstat_jaccard_df$jaccard >0.7) %>%
  ggplot(aes(x = document1, y = document2, fill = jaccard)) + 
  geom_tile() + 
  scale_fill_gradient(low = "white", high = "steelblue")

# Podemos utilizar la distancia entre los documentos para encontrar grupos similares
distMatrix <-dist(as.matrix(dfm_titlesQ_2),
                  method="euclidean")
groups <-hclust(distMatrix , method="ward.D")

#Draw the dendrogram with 10 aggrupations:
plot(groups,
     cex =0.25, #Size of labels
     hang= -1, #Same hight labels
     xlab = "", #Text of axis x
     ylab = "", #Text of axis y
     main = "" #Text of drawing
)
rect.hclust(groups, k=10)