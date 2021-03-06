#!/usr/bin/env Rscript
library(argparse)
library(ggplot2)
library(dplyr)
library(scales)
library(ggthemes)
library(ggrepel)

parser <-
  ArgumentParser(description = "", formatter_class = "argparse.RawTextHelpFormatter")
parser$add_argument("-i", "--infile", type = "character",
                    help = "result file generated by run.pl")
parser$add_argument("-o", "--outfile", type = "character",
                    default = "",
                    help = "result figure file")
parser$add_argument("--width", type = "double",
                    default = 8,
                    help = "result file width")
parser$add_argument("--height", type = "double",
                    default = 6,
                    help = "result file height")
parser$add_argument("--lx", type = "double",
                    default = 0.85,
                    help = "x of legend position")
parser$add_argument("--ly", type = "double",
                    default = 0.25,
                    help = "y of legend position")
parser$add_argument("--dpi", type = "integer",
                    default = 300,
                    help = "DPI")
parser$add_argument("--labcolor", type = "character",
                    default = "Tools",
                    help = "label of color")
parser$add_argument("--labshape", type = "character",
                    default = "Datasets",
                    help = "label of shape")

args <- parser$parse_args()

if (is.null(args$infile)) {
  write("ERROR: Input file (generated by run.pl) needed!\n", file = stderr())
  quit("no", 1)
}
if (args$outfile == "") {
  args$outfile = paste(args$infile, ".png", sep = "")
}

w <- args$width
h <- args$height

df <- read.csv(args$infile, sep = "\t")

# sort
df$test <- factor(df$test, levels = unique(df$test), ordered = TRUE)
df$app <- factor(df$app, levels = unique(df$app), ordered = TRUE)
df$dataset <-
  factor(df$dataset, levels = unique(df$dataset), ordered = TRUE)

# humanize mem unit
max_mem <- max(df$mem)
unit <- "KB"
if (max_mem > 1024 * 1024) {
  df <- df %>% mutate(mem2 = mem / 1024 / 1024)
  unit <- "GB"
} else if (max_mem > 1024) {
  df <- df %>% mutate(mem2 = mem / 1024)
  unit <- "MB"
} else {
  df <- df %>% mutate(mem2 = mem / 1)
  unit <- "KB"
}

df2 <- df %>%
  group_by(test, dataset, app) %>%
  summarize(
    mem_stdev = sd(mem2) / sqrt(length(mem2)),
    mem_mean = mean(mem2),
    time_stdev = sd(time) / sqrt(length(time)),
    time_mean = mean(time)
  )

p <-
  ggplot(
    df2, aes(
      x = mem_mean, y = time_mean,
      xmin = mem_mean - mem_stdev,
      xmax = mem_mean + mem_stdev,
      ymin = time_mean - time_stdev,
      ymax = time_mean + time_stdev,
      color = app, label = app
    )
  ) +
  
  geom_hline(aes(yintercept = time_mean, color = app), size = 0.25, alpha = 0.4) +
  geom_vline(aes(xintercept = mem_mean, color = app), size = 0.25, alpha = 0.4) +
  
  geom_point(size = 3.5) +
  
#   geom_errorbar(width = 20,  size = 1, alpha = 1) +
#   geom_errorbarh(height = 20/max(df$mem2)*max(df$time), 
#                  size = 1, alpha = 1) +
#   
#   geom_errorbar(aes(ymin = time_mean, ymax = time_mean), 
#                 width = 40, size = 1, alpha = 1) +
#   geom_errorbarh(aes(xmin = mem_mean, xmax = mem_mean), 
#                  height = 40/max(df$mem2)*max(df$time), 
#                  size = 1, alpha = 1) +
#   
#   geom_point(data=df, aes(x = mem2, y = time,
#                           xmin=NULL, xmax=NULL, 
#                           ymin=NULL, ymax=NULL),
#              size = 1.5, alpha = 0.6) +
  
  geom_text_repel(size = 5, max.iter = 200000) +
  # scale_color_wsj() +
  scale_color_colorblind() +
  facet_wrap( ~ dataset, scales = "free_y") +
  # ylim(0, max(df$time)) +
  xlim(0, max(df$mem2)) +
  
  # ggtitle(paste("FASTA/Q Manipulation Performance\n", test1, sep = "")) +
  ylab("Time (s)") +
  xlab(paste("Peak Memory (", unit, ")", sep = "")) +
  labs(color = args$labcolor, shape = args$labshape)

p <- p +
  theme_bw() +
  theme(
    panel.border = element_rect(color = "black", size = 1),
    panel.background = element_blank(),
    panel.grid.major = element_blank(),
    panel.grid.minor = element_blank(),
    plot.margin = unit(c(0.1,0.4,0.1,0.1),"cm"),
    # axis.ticks.y = element_line(size = 0.6),
    # axis.ticks.x = element_line(size = 0.6),
    # axis.line.x = element_line(colour = "black", size = 0.6),
    # axis.line.y = element_line(colour = "black", size = 0.6),
    
    
    strip.background = element_rect(
      colour = "white", fill = "white",
      size = 0.2
    ),
    
    legend.text = element_text(size = 14),
    # legend.position = c(args$lx,args$ly),
    legend.position = "none",
    # legend.background = element_rect(fill = "transparent"),
    # legend.key.size = unit(0.6, "cm"),
    # legend.key = element_blank(),
    # legend.text.align = 0,
    # legend.box.just = "left",
    # strip.text.x = element_text(angle = 0, hjust = 0),
    
    text = element_text(
      size = 14, family = "arial", face = "bold"
    ),
    plot.title = element_text(size = 15)
  )

if (grepl("tiff?$", args$outfile, perl = TRUE, ignore.case = TRUE)) {
  ggsave(
    p, file = args$outfile, width = w, height = h, dpi = args$dpi, compress =
      "lzw"
  )
} else {
  ggsave(
    p, file = args$outfile, width = w, height = h, dpi = args$dpi
  )
}

#   p <- p + scale_color_manual(values = rep("black", length(df$app)))
#
#   ggsave(
#     p, file = paste("benchmark-", gsub(" ", "-", tolower(test1)), ".grey.png", sep = ""), width = w, height = h
#   )
