#!/usr/bin/Rscript

args <- commandArgs(TRUE)
directory <- args[1]
miller_file <- args[2]
property <- args[3]
library("ggplot2", lib = "C:/Program Files (x86)/structuprint/R_libs")
	ending <- "structuprint.png"
	name <- paste(directory, ending, sep = "/")
	png(filename = name, width = 1700, height = 1700, units = "px", bg = "black")
	
	x <- read.table(miller_file, colClasses=c(NA, "NULL", "NULL"))
	x <- as.vector(x$V1)
	
	y <- read.table(miller_file, colClasses=c("NULL", NA, "NULL"))
	y <- as.vector(y$V2)
	
	Charge <- read.table(miller_file, colClasses=c("NULL", "NULL", NA))
	Charge <- as.vector(Charge$V3)
	
	dat <- data.frame(cond = Charge, xvar = x, yvar = y)
	ggplot(dat, aes(x = x, y = y, color = Charge)) + labs(colour = property) + geom_point() + scale_colour_gradientn(colours = c("blue", 
    "white", "red")) + theme(panel.background = element_rect(fill = "black"), panel.grid.major.x = element_blank(), 
    panel.grid.major.y = element_blank(), panel.grid.minor.x = element_blank(), panel.grid.minor.y = element_blank())
	
	invisible(dev.off())
