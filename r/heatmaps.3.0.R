pkgs <- c('RColorBrewer', 'pvclust', 'gplots', 'vegan')
lapply(pkgs, require, character.only = TRUE)

## increase ctt to get more clusters. Stay in range [ .5 - 3 ]
ctt=1.5

# Load data in matrix form
genre <- as.matrix(read.table("expressions", header = TRUE, row.names = 1))
gct <- dim(genre)[1]


## debugging
## START ##

## resampling
#tenpercent <- c(gct * .1)
#selected <- sample(gct, tenpercent)
#rawdata <- genre[selected, ]
#rawdata <- decostand(x = rawdata, method = s)
#scaledata=scale(rawdata)

## output analyses done for debugging purposes
## create an iterative counter and initialize it
icc <- function(){ i=0; function(){ i <<- i + 1;  i }}
ite <- icc()
steps_done="tmp"
                    
### END ###

# choose color palettes
#display.brewer.all()
palette.gr <- brewer.pal(11, name = "PiYG")
palette.rd <- brewer.pal(9, name = "YlOrRd")
palette.green <- colorRampPalette(palette.gr)(n = c(gct * .05))
palette.red <- colorRampPalette(palette.rd)(n = c(gct * .05))


## "standardize", "range", "hellinger", "log"
## complete, ward.D2, average
standardize_df <- c("hellinger")
normalize_df <- c("complete")
correlate_rows <- c("pearson", "spearman")
correlate_columns <- c("pearson", "spearman")


for ( s in standardize_df ) {
    for ( n in normalize_df ) {
        for ( cr in correlate_rows ) {
            for ( cc in correlate_columns ) {

                # standardization
                genre <- decostand(x = genre, method = s)
                
                ## HIERARCHICAL AND BOOTSTRAP ANALYSIS
                ## set measures to one same scale

                ## clustering by sample (columns)
                rawdata <- t(genre)
                ## clustering by genes/species (rows)
                rawdata <- genre

                scaledata=scale(rawdata)

                ## Clustering using dissimilarity analysis
                # use "pairwise.complete.obs" when generating NAs
                #hra <- hclust(as.dist(1-cor(t(scaledata), method="pearson",use = "pairwise.complete.obs")), method="average")
                hra <- hclust(as.dist(1-cor(t(scaledata), method= cr)), method= n)
                hca <- hclust(as.dist(1-cor(scaledata, method= cc)), method= n)


                ## cut tree
                mycl.row <- cutree(hra, h=max(hra$height)/ctt)
                mycl.col <- cutree(hca, h=max(hca$height)/ctt)

                ## attribute colors to clusters
                maxClusters.row <- length(unique(mycl.row))
                maxClusters.col <- length(unique(mycl.col))                

                ## color dendro clusters
                if ( maxClusters.row <= 12) {
                    myrowhc <- brewer.pal(maxClusters.row, name = 'Paired')
                } else {
                    myrowhc <- colorRampPalette(brewer.pal(8, name="Dark2"))(maxClusters.row)
                }

                ## Clustering features
                if ( maxClusters.col <= 12) {
                    mycolhc <- brewer.pal(maxClusters.col, name = 'Paired')
                } else {
                    mycolhc <- colorRampPalette(brewer.pal(9, name="Set1"))(maxClusters.col)
                }

                myrowhc <- myrowhc[as.vector(mycl.row)]
                mycolhc <- mycolhc[as.vector(mycl.col)]                




                ## BOOTSTRAPING to create pvalues
                # multiscale bootstrap resampling
                bst=500
                ## interval confidence (5% chance wrong clustering)
                a=0.95
                pvData.row <- pvclust(t(scaledata), method.dist="correlation",
                                      method.hclust= n, nboot= bst, parallel=TRUE)                
                pvData.col <- pvclust(scaledata, method.dist="correlation",
                                      method.hclust= n, nboot= bst, parallel=TRUE)

                write.table(print(pvData.row),file=paste0("bootstrap.PVAL",c(a*100),"p.STD",
                                                          s,".CLU",n,".VAR-CORR",cr,
                                                          ".FEA-CORR",cc,".BST",bst,".txt"),
                            row.names=FALSE, sep="\t", quote=FALSE) 

                write.table(print(pvData.col),file=paste0("bootstrap.PVAL",c(a*100),"p.STD",
                                                          s,".CLU",n,".VAR-CORR",cr,
                                                          ".FEA-CORR",cc,".BST",bst,".txt"),
                            row.names=FALSE, sep="\t", quote=FALSE) 
                
                
                # boostrapping genes
                pdf(paste("bootstrap.genes.STD",s,".CLU",n,".VAR-CORR",cr,".FEA-CORR",cc,".BST",bst,".pdf", sep = ""))
                plot(pvData.row, hang=-1, cex.pv=.2, cex=.2, float=0)
                pvrect(pvData.row, alpha=a, pv="au", type="geq", cex.lab=.3)
                dev.off()

                pdf(paste("standardErrors.bootstrappedgenes.STD",s,".CLU",n,".VAR-CORR",cr,".FEA-CORR",cc,".BST",bst,".pdf", sep = ""))
                seplot(pvData.row, type=c("au", "bp"))
                dev.off()

                # bootstrapping samples
                pdf(paste("bootstrap.cases.STD",s,".CLU",n,".VAR-CORR",cr,".FEA-CORR",cc,".BST",bst,".pdf", sep = ""))
                plot(pvData.col, hang=-1, cex.pv=.2, cex=.2, float=0)
                pvrect(pvData.col, alpha=a, pv="au", type="geq", cex.lab=.3)
                dev.off()

                pdf(paste("standardErrors.bootstrappedcases.STD",s,".CLU",n,".VAR-CORR",cr,".FEA-CORR",cc,".BST",bst,".pdf", sep = ""))
                seplot(pvData.col, type=c("au", "bp"))
                dev.off()

                
                
                ## RETRIEVE MEMBERS OF SIGNIFICANT CLUSTERS.
                clsig.row <- unlist(pvpick(pvData.row, alpha=a, pv="au", type="geq", max.only=TRUE)$clusters)
                clsig.col <- unlist(pvpick(pvData.col, alpha=a, pv="au", type="geq", max.only=TRUE)$clusters)                

                ## Function to Color Dendrograms
                dendroCol <- function(dend=dend, keys=keys, xPar="edgePar", bgr="red", fgr="blue", pch=20, lwd=1, ...) {
                    if(is.leaf(dend)) {
                        myattr <- attributes(dend)
                        if(length(which(keys==myattr$label))==1){
                            attr(dend, xPar) <- c(myattr$edgePar, list(lab.col=fgr, col=fgr, pch=pch, lwd=lwd))
                                        # attr(dend, xPar) <- c(attr$edgePar, list(lab.col=fgr, col=fgr, pch=pch))
                        } else {
                            attr(dend, xPar) <- c(myattr$edgePar, list(lab.col=bgr, col=bgr, pch=pch, lwd=lwd))
                        }
                    }
                    return(dend)
                }


                ## color the edges of the dendrogram based on 5000 bootstrap significance
                dend_colored.row <- dendrapply(as.dendrogram(pvData.row$hclust), dendroCol, keys=clsig.row, xPar="edgePar", bgr="black", fgr="red", pch=20)
                dend_colored.col <- dendrapply(as.dendrogram(pvData.col$hclust), dendroCol, keys=clsig.col, xPar="edgePar", bgr="black", fgr="red", pch=20)                


                ## PLOT HEATMAP
                pdf(paste("heatmap.green.STD",s,".CLU",n,".VAR-CORR",cr,".FEA-CORR",cc,".BST",bst,".pdf", sep = ""))
                heatmap.2(rawdata,
                          Rowv=dend_colored.row, Colv=dend_colored.col,
                          col=rev(palette.green),
                          scale="row", trace="none",
                          RowSideColors = myrowhc, ColSideColors=mycolhc,
                          margins=c(5,5), cexRow=.1, cexCol=.1)
                dev.off()


                pdf(paste("heatmap.red.STD",s,".CLU",n,".VAR-CORR",cr,".FEA-CORR",cc,".BST",bst,".pdf", sep = ""))
                heatmap.2(rawdata,
                          Rowv=dend_colored.row, Colv=dend_colored.col,
                          col=rev(palette.red),
                          scale="row", trace="none",
                          RowSideColors = myrowhc, ColSideColors=mycolhc,
                          margins=c(5,5), cexRow=.1, cexCol=.1)
                dev.off()
                


                ## output analyses done for debugging purposes
                if ( file.exists(steps_done) )
                    file.remove(steps_done)

                
                # increase counter by 1 and amend new methods succesfully executed
                steps_done=paste0("cluster.iteration_",ite(),".STD",s,".CLU",n,".VAR-CORR",cr,".FEA-CORR",cc,".BST",bst)


                if ( !file.exists(steps_done) )
                    file.create(steps_done)






            }
        }
    }
}
