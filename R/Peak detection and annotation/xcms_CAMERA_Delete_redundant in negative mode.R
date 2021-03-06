library(xcms)
library(MSnbase)
library(CAMERA)
library(stringr)

# Get the full path to the mzXML files
mzxml <- dir('D:\\github\\MRM-Ion_Pair_Finder\\Data\\mzXML',full.names = T,recursive = TRUE)
mzxml

# Peak detection & alignment
xset <- xcmsSet(mzxml, ppm = 20, snthresh = 3, method = 'centWave', peakwidth = c(8, 30), noise= 1000)
xset2 <- group(xset, minfrac = 1)
xset2 <- retcor(xset2, method = 'obiwarp', plottype = 'deviation')
xset2 <- group(xset2, bw = 20, minfrac = 1)

# Filling gaps
xset3 <- fillPeaks(xset2)
feature.info <- xcms::groups(xset3)

# Create an xsAnnotate object
xa <- xsAnnotate(xset3)
# Group after RT value of the xcms grouped peak
xag <- groupFWHM(xa, perfwhm=0.6)
# Verify grouping
xac <- groupCorr(xag)

# Annotate isotopes, could be done before groupCorr
xac.isotope <- findIsotopes(xac)

# Annotate adducts
xac.addu <- findAdducts(xac.isotope, polarity="negative")

# Get final peaktable and store on harddrive
res.anno <- getPeaklist(xac.addu)
write.csv(res.anno,file="D:\\github\\MRM-Ion_Pair_Finder\\Data\\mzXML\\Peak dectection Result.csv")

# Remove redundant features 
csv_file <- read.csv('D:\\github\\MRM-Ion_Pair_Finder\\Data\\mzXML\\Peak dectection Result.csv')
csv_file <- as.vector(csv_file)
isotopePosi <- which(colnames(csv_file)=='isotopes')
adductPosi <- which(colnames(csv_file)=='adduct')
pcgroupPosi <- which(colnames(csv_file)=='pcgroup')
isotope <- as.character(csv_file[, isotopePosi])

for (i in (c(length(isotope) : 1)))
{
	iso_format <- isotope[i]
	iso_format <- str_replace_all(iso_format,"\\[(.*?)\\+","")
	iso_format <- str_replace_all(iso_format,"\\](.*?)\\-","")
	iso_format <- as.numeric(iso_format)

	if (is.na(iso_format) == FALSE)
	{
		csv_file <- csv_file[-i,]
	}
}

Adduct <- as.vector(csv_file[, adductPosi])
pcgroup <- as.vector(csv_file[, pcgroupPosi])

for (i in (c(length(Adduct) : 2)))
{
	add_format <- Adduct[i]
	counti <- str_count(add_format, ' ')
	if (counti == 1)
	{
		add <- sapply(str_split(add_format,' '),'[',1) 
		mz_m <- sapply(str_split(add_format,' '),'[',2)
		for (j in c((i-1) : 1)) 
		{
			add_format2 <- Adduct[j]
			countj <- str_count(add_format2, ' ')
			if (countj == 1)
			{
				mz_m12 <- str_subset(add_format2, mz_m)
				if (length(str_length(mz_m12)) >= 1 & pcgroup[i] == pcgroup[j])
				{
					int_i <- csv_file[i,10:(isotopePosi-1)]
					int_j <- csv_file[j,10:(isotopePosi-1)]
					if (int_i >= int_j)
					{
						csv_file[j,] <- csv_file[i,] 
					}
					else
					{
						csv_file[i,] <- csv_file[j,]
					}
				}
			}
			
		}
	}
	else if (counti > 2)
	{
		delete_count <- 0
		num_adduct <- (counti+1)/2 
		mz_add_format <- gsub("\\[.*?\\- ","",add_format) 
		mz_vector <- unlist(strsplit(mz_add_format,split=" "))
		for (k in mz_vector)
		{
			 
			for (j in c((i-1) : 1))
			{
				add_format2 <- Adduct[j]
				countj <- str_count(add_format2, ' ')
				if (countj >= 1)
				{
					mz_m12 <- str_subset(add_format2, k)
					if (length(str_length(mz_m12)) >= 1 & pcgroup[i] == pcgroup[j])
					{
					  int_i <- sum(csv_file[i,10:(isotopePosi-1)])
					  int_j <- sum(csv_file[j,10:(isotopePosi-1)])
						if (int_i <= int_j)
						{
							delete_count <- delete_count + 1
						 
						}
					}
				}
			}
		}
		if (length(mz_vector) == delete_count)
		{
			csv_file[i,] <- csv_file[j,]
		}
				
	}
}
csv_file <- unique(csv_file)
csv_file <- csv_file[,-adductPosi]
csv_file <- csv_file[,-isotopePosi]
write.csv(csv_file,'D:\\github\\MRM-Ion_Pair_Finder\\Data\\mzXML\\Delete Iso-Add Result.csv')