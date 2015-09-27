# Check if a package is installed.
is.installed <- function(mypkg){
    is.element(mypkg, installed.packages()[,1])
} 

# Make sure that required packages are installed.
req_packages <- c('ggplot2', 'grid', 'scales', 'labeling')
results <- is.installed(req_packages)

for (i in 1:length(results))
{
	if (!(results[i]))
	{
		stop(paste("Package ", req_packages[i], " was not found!", sep = ""))
	}
}

# Make sure that ggplot2's version is at least 1.0.0
if (compareVersion(as.character(packageVersion('ggplot2')), '1.0.0') == -1)
{
	stop("The version of ggplot2 is older than 1.0.0!")
}
