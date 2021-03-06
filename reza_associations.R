options(warn=1)
library(gridExtra)
library(vcd)
library(tidyr)

rm(list=ls())

set.seed(22)

c <- read.delim("/mnt/projects/reza/data/Samples_Reza-v2.txt", na.strings=c("", "NA", "n/a", "N/A", "n/d", " "), check.names=F)

#---
# TYPE1: sample groups according to column Type1
#---

# convert to wide format
cw.type1 <- unique(c[!is.na(c$Type1),c("Pts. No.", "Age at Dx (M)", "Age (>=18 M)", "OS (M)", "OS Status", "EFS (M)", "EFS Status", "Relaspe/Progression", "Dead", "Gender")])
for(col in names(c)[14:ncol(c)]) {
  attrib <- c[!is.na(c$Type1),c("Pts. No.", "Type1", col)] ; names(attrib) <- c("Pts. No.", "key", "value")
  attrib <- spread(attrib, key, value) ; names(attrib) <- c("Pts. No.", paste0(col, ".", names(attrib)[-1]))
  cw.type1 <- merge(cw.type1, attrib)
}

pdf("/mnt/projects/reza/results/reza_associations.type1.pdf")
tests <- test_pairwise_assoc(cw.type1, 
                             sig.level=0.1, 
                             exclude=c("Pts. No."),
                             exclude.group=list(
                               c("Type1", "Type2")
                             )
)
dev.off()

#---
# TYPE2: sample groups according to column Type2
#---

# convert to wide format
cw.type2 <- unique(c[!is.na(c$Type2),c("Pts. No.", "Age at Dx (M)", "Age (>=18 M)", "OS (M)", "OS Status", "EFS (M)", "EFS Status", "Relaspe/Progression", "Dead", "Gender")])
for(col in names(c)[14:ncol(c)]) {
  attrib <- c[!is.na(c$Type2),c("Pts. No.", "Type2", col)] ; names(attrib) <- c("Pts. No.", "key", "value")
  attrib <- spread(attrib, key, value) ; names(attrib) <- c("Pts. No.", paste0(col, ".", names(attrib)[-1]))
  cw.type2 <- merge(cw.type2, attrib)
}

pdf("/mnt/projects/reza/results/reza_associations.type2.pdf")
tests <- test_pairwise_assoc(cw.type2, 
                             sig.level=0.1, 
                             exclude=c("Pts. No."),
                             exclude.group=list(
                               c("Type1", "Type2")
                             )
)
dev.off()


test_pairwise_assoc <- function (df, include=NULL, exclude=NULL, sig.level=NULL, include.group=NULL, exclude.group=NULL) {
  
  tests <- data.frame(a = character(0), b = character(0), type = character(0), p = numeric(0), R = numeric(0), stringsAsFactors=F)
  for (i in 1:(ncol(df)-1)) {
    for (j in (i+1):ncol(df)) {
      
      name.a <- names(df)[i]
      name.b <- names(df)[j]
      
      if (!is.null(include) && !(name.a %in% include) && !(name.b %in% include)) next
      if (!is.null(exclude) && (name.a %in% exclude || name.b %in% exclude)) next
      if (!is.null(include.group) && (!(name.a %in% include.group) || !(name.b %in% include.group))) next
      if (!is.null(exclude.group)) {
        found = FALSE
        for (g in 1:length(exclude.group)) {
          if (name.a %in% exclude.group[[g]] && name.b %in% exclude.group[[g]]) {
            found = TRUE
            break
          }
        }
        if (found) {
          print(paste0("Excluding within-group comparison '", name.a, "' and '", name.b, "'"))
          next
        }
      }
      
      a <- df[,i]
      b <- df[,j]
      
      if ((is.factor(a) || is.logical(a)) && is.numeric(b)) {
        print(paste0("CATEGORIAL VS. NUMERIC: ", names(df)[i], " <--> ", names(df)[j]))
        if (length(levels(as.factor(as.character(a[!is.na(b)])))) > 1) { # we need more than one group
          test <- kruskal.test(b~a, na.action=na.exclude)
          tests[nrow(tests)+1,] <- c(name.a, name.b, "CAT-vs-NUM", test$p.value, NA)
        } else {
          print(paste0("  NO TEST PERFORMED: only single factor level: ", unique(a[!is.na(b)])));
        }
      } else if (is.numeric(a) && (is.factor(b) || is.logical(b))) {
        print(paste0("NUMERIC VS. CATEGORIAL: ", names(df)[i], " <--> ", names(df)[j]))
        if (length(levels(as.factor(as.character(b[!is.na(a)])))) > 1) { # we need more than one group
          test <- kruskal.test(a~b, na.action=na.exclude)
          tests[nrow(tests)+1,] <- c(name.b, name.a, "CAT-vs-NUM", test$p.value, NA)
        } else {
          print(paste0("  NO TEST PERFORMED: only single factor level: ", unique(b[!is.na(a)])));
        }
      } else if (is.numeric(a) & is.numeric(b)) {
        print(paste0("NUMERIC VS. NUMERIC: ", names(df)[i], " <--> ", names(df)[j]))
        fit <- lm(b~a)
        p <- anova(fit)$'Pr(>F)'[1]
        tests[nrow(tests)+1,] <- c(name.a, name.b, "NUM-vs-NUM", p, summary(fit)$r.squared)
      } else if ((is.factor(a) || is.logical(a)) && (is.factor(b) || is.logical(b))) {
        print(paste0("CATEGORIAL VS. CATEGORIAL: ", names(df)[i], " <--> ", names(df)[j]))
        pair.table <- table(df[,c(i, j)])
        if (sum(pair.table > 0)) {
          p <- fisher.test(pair.table, workspace=1e+9)$p.value
          tests[nrow(tests)+1,] <- c(name.a, name.b, "CAT-vs-CAT", p, NA)
        }
      }
    }
  }
  
  # sort results by p-value
  tests$p <- as.numeric(tests$p)
  tests$R <- as.numeric(tests$R)
  tests <- tests[order(tests$p),]
  
  # plot results
  for (i in 1:nrow(tests)) {
    if (!is.null(sig.level) && tests[i,"p"] > sig.level) break
    
    name.a <- tests[i, "a"]
    name.b <- tests[i, "b"]
    a <- df[,name.a]
    b <- df[,name.b]
    
    if (tests[i,"type"] == "CAT-vs-NUM") {
      boxplot(b~a, xlab=name.a, ylab=name.b, main=sprintf("p=%.2g", tests[i, "p"]), na.action=na.exclude, outline=F, cex.axis=0.8)
      stripchart(b~a, method="jitter", na.action=na.exclude, vertical=T, pch=19, col=1:length(levels(as.factor(a))), add=T)
    } else if (tests[i,"type"] == "NUM-vs-NUM") {
      plot(a, b, xlab=name.a, ylab=name.b, main=sprintf("R=%.2f, p=%.2g", tests[i, "R"], tests[i, "p"]))
      abline(lm(b~a), col="red")
    } else if (tests[i,"type"] == "CAT-vs-CAT") {
      pair.table <- table(df[,c(name.a, name.b)])
      mosaic(pair.table, pop=F, main=sprintf("p=%.2g", tests[i, "p"]))
      labeling_cells(text=pair.table)(pair.table)
    }
  }
  
  return(tests)
}