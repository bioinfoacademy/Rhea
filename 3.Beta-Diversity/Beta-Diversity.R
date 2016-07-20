#' Version 1.0
#' Last modified on 14/06/2016
#' Script: Beta-Diversity
#' Author: Ilias Lagkouvardos
#'
#' Calculate beta-diversity for microbial communities
#' based on permutational mulitvariate analysis of variances (PERMANOVA) using multiple distance matrices
#' computed from phylogenetic distances between observed organisms
#'
#' Input:
#' 1. Set the path to the directory where the file is stored 
#' 2. Write the name of the normalized OTU table without taxonomy information 
#' 3. Write the name of the mapping file that includes the samples groups
#' 4. Write the name of the OTU tree
#' 5. Write the name of the variable (sample group) used for comparison 
#'
#' Output: 
#' The script generates three graphical outputs (pdf) and one text file
#' 1. A phylogram with colour-coded group clustering
#' 2. MDS and NMDS plots showing information about beta-diversity across all sample groups
#' 3. MDS and NMDS plots of all pairwise comparisons
#' 4. The distance matrix
#'
#' Concept:
#' A distance matrix is calculated based on the generalized UniFrac approach
#' (Chen J, et al. Associating microbiome composition with environmental covariates using generalized UniFrac distances. 2012)
#' Samples are clustered based on the distance matrix using the Ward's hierarchical clustering method
#' To determine similarities between samples, a multivariate analysis is applied
#' and sample distribution is illustrated by means of MDS and NMDS (non-metric) plots

##################################################################################
######             Set parameters in this section manually                  ######
##################################################################################

#' Please set the directory of the script as the working folder (e.g D:/studyname/NGS-Data/Rhea/beta-diversity/)
#' Note: the path is denoted by forward slash "/"
setwd("D:/imngs-toolbox/Rhea/3.Beta-Diversity/")  #<--- CHANGE ACCORDINGLY !!!

#' Please give the file name of the normalized OTU-table without taxonomic classification
input_otu = "OTUs_Table-norm.tab"              #<--- CHANGE ACCORDINGLY !!!

#' Please give the name of the meta-file that contains individual sample information
input_meta = "mapping_file.tab"                #<--- CHANGE ACCORDINGLY !!!

#' Please give the name of the phylogenetic tree constructed from the OTU sequences
input_tree = "OTUs-Tree.tre"                   #<--- CHANGE ACCORDINGLY !!!

#' Please give the column name (in the mapping file) of the categorical variable to be used for comparison (e.g. Genotype)
group_name = "Genotype"                   #<--- CHANGE ACCORDINGLY !!!

##################################################################################
######                  Additional parameters                               ######
##################################################################################

#' Turn on sample labeling
#' 0 = Samples are not labeled in the MDS/NMDS plots
#' 1 = All Samples are labed in the MDS/NMDS plots
label_samples = 0

#' Determine which sample lable should appear
#' Write the name of samples (in quotation marks), which should appear in the MDS/NMDS plots, in the vector (c) below
#' If more than one sample should be plotted, please separate their IDs by comma (e.g. c("sample1","sample2"))
label_id =c("")

######                  NO CHANGES ARE NEEDED BELOW THIS LINE               ######

##################################################################################
######                             Main Script                              ######
##################################################################################

###################       Load all required libraries     ########################

# Check if required package ade4 is already installed, and install if missing
if (!require("ade4")) {install.packages("ade4")}

# Check if required package GUniFrac is already installed, and install if missing
if (!require("GUniFrac")) {install.packages("GUniFrac")}

# Check if required package phangorn is already installed, and install if missing
if (!require("phangorn"))  {install.packages("phangorn")}

# Check if required package randomcoloR is already installed, and install if missing
if (!require("randomcoloR"))  {install.packages("randomcoloR")}

# Check if required package Rcpp is already installed, and install if missing
if (!require("Rcpp"))  {install.packages("Rcpp")}

# Load and attach required packages
library(GUniFrac)
library(ade4)
library(phangorn)
library(randomcoloR)

###################       Read all required input files      ####################

# Load the tab-delimited file containing the values to be analyzed (samples names in the first column)
otu_file <- read.table (file = input_otu, check.names = FALSE, header = TRUE, dec = ".", sep = "\t", row.names = 1, comment.char = "")

# Load the mapping file containing individual sample information (sample names in the first column)
meta_file <- read.table (file = input_meta, check.names = FALSE, header = TRUE, dec = ".", sep = "\t", row.names = 1, comment.char = "")

# Load the phylogenetic tree calculated from the OTU sequences 
tree_file <- read.tree(input_tree)

# Create the directory where all output files are saved (is named after the target group name set above for comparisons)
dir.create(group_name)

####################       Calculate beta-diversity          ###################

# OTU-table and mapping file should have the same order and number of sample names
# Order the OTU-table by sample names (ascending)
otu_file <- otu_file[,order(names(otu_file))]

# Transpose OTU-table and convert format to a data frame
otu_file <- data.frame(t(otu_file))

# Order the mapping file by sample names (ascending)
meta_file <- meta_file[order(row.names(meta_file)),]

# Save the position of the target group name in the mapping file
meta_file_pos <- which(colnames(meta_file) == group_name)

# Select metadata group based on the pre-set group name
all_groups <- meta_file[,meta_file_pos]

# Root the OTU tree at midpoint 
rooted_tree <- midpoint(tree_file)

# Calculate the UniFrac distance matrix for comparing microbial communities
unifracs <- GUniFrac(otu_file, rooted_tree, alpha = c(0.0,0.5,1.0))$unifracs

# Weight on abundant lineages so the distance is not dominated by highly abundant lineages with 0.5 having the best power
unifract_dist <- unifracs[, , "d_0.5"]

################ Generate tree #######################

# Save the UniFrac output as distance object
all_dist_matrix <- as.dist(unifract_dist)

# Apply a hierarchical cluster analysis on the distance matrix based on the Ward's method
all_fit <- hclust(all_dist_matrix, method = "ward.D2")

# Generates a tree from the hierarchically generated object
tree <- as.phylo(all_fit)
my_tree_file_name <- paste(group_name,"/phylogram.pdf",sep="")
plot_color<-distinctColorPalette(length(levels(all_groups)))[all_groups]

# Save the generated phylogram in a pdf file
pdf(my_tree_file_name)

# The tree is visualized as a Phylogram color-coded by the selected group name
plot(tree, type = "phylogram",use.edge.length = TRUE, tip.color = (plot_color), label.offset = 0.01)
print.phylo(tree)
axisPhylo()
tiplabels(pch = 16, col = plot_color)
dev.off()

#################            Build NMDS plot           ########################

# Generated figures are saved in a pdf file 
file_name <- paste(group_name,"beta-diversity.pdf",sep="_")
pdf(paste(group_name,"/",file_name,sep=""))

# Calculate the significance of variance to compare multivariate sample means (including two or more dependent variables)
adonis<-adonis(as.dist(unifract_dist) ~ all_groups)
all_groups<-factor(all_groups,levels(all_groups)[unique(all_groups)])

# Calculate and display the MDS plot (Multidimensional Scaling plot)
s.class(
  cmdscale(unifract_dist, k = 2), col = unique(plot_color), cpoint =
    2, fac = all_groups, sub = paste("MDS plot of Microbial Profiles\n(p-value",adonis[[1]][6][[1]][1],")",sep="")
)
if (label_samples==1) {
  lab_samples <- row.names(cmdscale(unifract_dist, k = 2))
  ifelse (label_id != "",lab_samples <- replace(lab_samples, !(lab_samples %in% label_id), ""), lab_samples)
  text(cmdscale(unifract_dist, k = 2),labels=lab_samples,cex=0.7,adj=c(-.1,-.8))
}

# Calculate and display the NMDS plot (Non-metric Multidimensional Scaling plot)
meta <- metaMDS(unifract_dist,k = 2)
s.class(
  meta$points, col = unique(plot_color), cpoint = 2, fac = all_groups,
  sub = paste("metaNMDS plot of Microbial Profiles\n(p-value",adonis[[1]][6][[1]][1],")",sep="")
)
if (label_samples==1){
  lab_samples <- row.names(meta$points)
  ifelse (label_id != "",lab_samples <- replace(lab_samples, !(lab_samples %in% label_id), ""), lab_samples)
  text(meta$points,labels=lab_samples,cex=0.7,adj=c(-.1,-.8))
}

#close the pdf file
dev.off()

###############          NMDS for pairwise analysis        ###################

# This plot is only generated if there are more than two groups included in the comparison
# Calculate the pairwise significance of variance for group pairs
# Get all groups contained in the mapping file
unique_groups <- levels(all_groups)
if (dim(table(unique_groups)) > 2) {

# Initialise vector and lists
pVal = NULL
pairedMatrixList <- list(NULL)
pair_1_list <- NULL
pair_2_list <- NULL

for (i in 1:length(combn(unique_groups,2)[1,])) {
 
  # Combine all possible pairs of groups
  pair_1 <- combn(unique_groups,2)[1,i]
  pair_2 <- combn(unique_groups,2)[2,i]
  
  # Save pairs information in a vector
  pair_1_list[i] <- pair_1
  pair_2_list[i] <- pair_2
    
  # Generate a subset of all samples within the mapping file related to one of the two groups
  inc_groups <-
    rownames(subset(meta_file, meta_file[,meta_file_pos] == pair_1
                    |
                      meta_file[,meta_file_pos] == pair_2))
  
  # Convert UniFrac distance matrix to data frame
  paired_dist <- as.data.frame(unifract_dist)
  
  # Save all row names of the mapping file
  row_names <- rownames(paired_dist)
  
  # Add row names to the distance matrix
  paired_dist <- cbind(row_names,paired_dist)
  
  # Generate distance matrix with samples of the compared groups (column-wise)
  paired_dist <- paired_dist[sapply(paired_dist[,1], function(x) all(x %in% inc_groups)),]
  
  # Remove first column with unnecessary group information
  paired_dist[,1] <- NULL
  paired_dist <- rbind(row_names,paired_dist)
  
  # Generate distance matrix with samples of the compared group (row-wise)
  paired_dist <- paired_dist[,sapply(paired_dist[1,], function(x) all(x %in% inc_groups))]
  
  # Remove first row with unnecessary group information 
  paired_dist <- paired_dist[-1,]
  
  # Convert generated distance matrix to data type matrix (needed by multivariate analysis)
  paired_matrix <- as.matrix(paired_dist)
  class(paired_matrix) <- "numeric"
  
  # Save paired matrix in list
  pairedMatrixList[[i]] <- paired_matrix
  
  # Applies multivariate analysis to a pair out of the selected groups
  adonis <- adonis(paired_matrix ~ all_groups[all_groups == pair_1 |
                                            all_groups == pair_2])
  
  # List p-values
  pVal[i] <- adonis[[1]][6][[1]][1]
  
}

# Adjust p-values for multiple testing according to Benjamini-Hochberg method
pVal_BH <- p.adjust(pVal,method="BH", n=length(pVal))

# Generated NMDS plots are stored in one pdf file called "pairwise-beta-diversity.pdf"
file_name <- paste(group_name,"pairwise-beta-diversity.pdf",sep="_")
pdf(paste(group_name,"/",file_name,sep=""))

for(i in 1:length(combn(unique_groups,2)[1,])){
    meta <- metaMDS(pairedMatrixList[[i]], k = 2)
    s.class(
      meta$points,
      col = distinctColorPalette(length(levels(all_groups))), cpoint = 2,
      fac = as.factor(all_groups[all_groups == pair_1_list[i] |
                                   all_groups == pair_2_list[i]]),
      sub = paste("NMDS plot of Microbial Profiles\n ",pair_1_list[i]," - ",pair_2_list[i], "\n(p-value ",pVal[i],","," corr. p-value ", pVal_BH[i],")",sep="")
    )
}
dev.off()

}

#################################################################################
######                        Write Output Files                           ######
#################################################################################

# Write the distance matrix table in a file
file_name <- paste(group_name,"distance-matrix-gunif.tab",sep="_")
write.table( unifract_dist, paste(group_name,"/",file_name,sep=""), sep = "\t", col.names = NA, quote = FALSE)

# Graphical output files are generated in the main part of the script

#################################################################################
######                           End of Script                             ######
#################################################################################