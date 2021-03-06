library(biomaRt)
library(tidyverse)
library(magrittr)


load("Robjects/DE.Rdata")

## set up connection to ensembl database
ensembl=useMart("ENSEMBL_MART_ENSEMBL")
ensembl = useDataset("mmusculus_gene_ensembl", mart=ensembl)

listAttributes(ensembl) %>% 
    head(n=40)

# get annot
filterType <- "ensembl_gene_id"
filterValues <- rownames(resLvV)

attributeNames <- c('ensembl_gene_id',
                    'entrezgene',
                    'external_gene_name',
                    'description',
                    'gene_biotype',
                    'chromosome_name',
                    'start_position',
                    'end_position',
                    'strand')

# Get annotations
annot <- getBM(attributes=attributeNames,
               filters = filterType,
               values = filterValues,
               mart = ensembl)

# get transcript length
txLen <- getBM(attributes=c('ensembl_gene_id', 'transcript_length'),
               filters = filterType,
               values = filterValues,
               mart = ensembl) %>% 
    group_by(ensembl_gene_id) %>% 
    summarise(transcript_length=median(transcript_length))

annot <- left_join(annot, txLen)

# There are 63 ensembl id's with multiple Entrez ID's
# Deduplicate the entrez IDS - just arbitrarily take the first

annotUn <- annot %>%
    filter(!duplicated(ensembl_gene_id))

# The problem: we now have 10 duplicated Entrez IDs
# fsgea throws a nasty warning about multiple genes if we have this issue
load("Robjects/DE.Rdata")
res <- as.data.frame(resLvV) %>% 
    rownames_to_column("ensembl_gene_id") %>% 
    mutate(ordFC=order(log2FoldChange))

filtAnnotUn <- filter(annotUn, !is.na(entrezgene))
dupsZ <- unique(filtAnnotUn$entrezgene[duplicated(filtAnnotUn$entrezgene)])
dupsE <- filtAnnotUn$ensembl_gene_id[filtAnnotUn$entrezgene %in% dupsZ]


annot %>% 
    filter(ensembl_gene_id%in%dupsE) %>% 
    group_by(ensembl_gene_id) %>% 
    mutate(Entrez=str_c(entrezgene, collapse=";")) %>%
    filter(!duplicated(ensembl_gene_id)) %>%
    left_join(res) %>% 
    dplyr::select(ensembl_gene_id, entrezgene, Entrez, ordFC, padj) %>% 
    arrange(Entrez) %>% 
    as.data.frame()

# we need a pragmatic solution for the course
# There are two that have multiple Entrez IDs, we can modify these to have
# different Entrez IDs
# For the others, they are mostly non-significant, we'll arbritrarily set the
# second entry above to NA
annotUnEnt <- annotUn
annotUnEnt$entrezgene[annotUnEnt$ensembl_gene_id=="ENSMUSG00000078941"] <- "102216272"
annotUnEnt$entrezgene[annotUnEnt$ensembl_gene_id=="ENSMUSG00000008450"] <- "621832"
annotUnEnt$entrezgene[annotUnEnt$ensembl_gene_id=="ENSMUSG00000071497"] <- "68051"
annotUnEnt$entrezgene[duplicated(annotUn$entrezgene)] <- NA
annotUnEnt %>% 
    filter(ensembl_gene_id%in%dupsE) %>% 
    dplyr::select(ensembl_gene_id, entrezgene) %>%
    as.data.frame()

# # get human homology for gsea
# attributeNames <- c('ensembl_gene_id',
#                     'hsapiens_homolog_associated_gene_name')
# homol <- getBM(attributes=attributeNames,
#                filters = filterType,
#                values = filterValues,
#                mart = ensembl)
# dupHomol <- homol %>%
#     group_by(ensembl_gene_id) %>%
#     mutate(Count=length(ensembl_gene_id)) %>%
#     filter(Count>1) %>%
#     arrange(ensembl_gene_id) %>%
#     select(-Count) %T>%
#     View()
# # remove duplicate entries - a pragmatic approach for the course
# # if all of the entries are "\\.[0-9]$" or contain "-"
# # (e.g. EPPIN-WFDC6 v EPPIN) keep the first
# # otherwise remove all "\\.[0-9]$" and keep the first remaining
# dedupHomol <- function(x){
#     notAC <- !(str_detect(x, "\\.[0-9]$|-"))
#     if(any(notAC)){ x <- x[notAC] }
#     x[1]
# }
# homolDeDup <- homol %>%
#     arrange(hsapiens_homolog_associated_gene_name) %>%
#     group_by(ensembl_gene_id) %>%
#     mutate(HumanHomolog=dedupHomol(hsapiens_homolog_associated_gene_name))
# homolDeDup %>%
#     group_by(ensembl_gene_id) %>%
#     mutate(Count=length(ensembl_gene_id)) %>%
#     filter(Count>1) %>%
#     arrange(ensembl_gene_id) %>%
#     select(-Count) %T>%
#     View()
# homolDeDup <- homolDeDup %>%
#     select(-hsapiens_homolog_associated_gene_name) %>%
#     filter(HumanHomolog!="") %>%
#     distinct()

### Final table

ensemblAnnot <- annotUnEnt %>%
    #left_join(homolDeDup) %>% 
    dplyr::rename(GeneID="ensembl_gene_id", Entrez="entrezgene",
              Symbol="external_gene_name", Description="description",
              Biotype="gene_biotype", Chr="chromosome_name",
              Start="start_position", End="end_position",
              Strand="strand", medianTxLength='transcript_length')

save(annot, file="Robjects/Full_annotation.RData")
save(ensemblAnnot, file="Robjects/Ensembl_annotations.RData")
