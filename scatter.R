d <- read.delim("Enrichment Results_Reza.txt", header=T)
pdf("scatter.pdf")
plot(d$TC_after, d$TC_before, col=d$group, pch=as.integer(d$group), xlim=c(0,100), xlab="TC after", ylab="TC before", log="y")
dev.off()

