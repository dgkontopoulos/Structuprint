#!/usr/bin/Rscript

####################################################################
#Author: Dimitrios - Georgios Kontopoulos <dgkontopoulos@gmail.com>#
####################################################################

####################################################################
#Script in the R programming language for plotting 'structuprints'.#
#Refer to structuprint's main documentation for more details.      #
####################################################################

###################################################################### 
#This program is free software: you can redistribute it and/or modify#
#it under the terms of the GNU General Public License as             #
#published by the Free Software Foundation, either version 2 of the  #
#License, or (at your option) any later version.                     #
#                                                                    #
#This program is distributed in the hope that it will be useful,     #
#but WITHOUT ANY WARRANTY; without even the implied warranty of      #
#MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the       #
#GNU General Public License for more details.                        #
#                                                                    #
#For more information, see http://www.gnu.org/licenses/.             #
######################################################################

args <- commandArgs(TRUE)
directory <- args[1]
miller_file <- args[2]
property <- args[3]
library("ggplot2", lib = "C:/Program Files (x86)/structuprint/R_libs")
library("grid")

ending <- "structuprint.png"
name <- paste(directory, ending, sep = "/")
png(filename = name, width = 1700, height = 1700, units = "px", bg = "black")

x <- read.table(miller_file, colClasses = c(NA, "NULL", "NULL"))
x <- as.vector(x$V1)

y <- read.table(miller_file, colClasses = c("NULL", NA, "NULL"))
y <- as.vector(y$V2)

Charge <- read.table(miller_file, colClasses = c("NULL", "NULL", NA))
Charge <- as.vector(Charge$V3)

dat <- data.frame(cond = Charge, xvar = x, yvar = y)
ggplot(dat, aes(x = x, y = y, color = Charge)) + labs(colour = property) + geom_point() + 
    scale_colour_gradientn(colours = c("blue", "white", "red")) + theme(panel.background = element_rect(fill = "black"), 
    panel.grid.major.x = element_blank(), panel.grid.major.y = element_blank(), panel.grid.minor.x = element_blank(), 
    panel.grid.minor.y = element_blank(), legend.title = element_text(size=30), legend.text = element_text(size = 30),
    legend.key.size = unit(1.5, "cm"))

invisible(dev.off()) 
