################################################################################
#        Build the data used by the Shiny app (colors + palettes)              #
#   Run once locally (needs paletteer, wesanderson and the palette packages    #
#   paletteer relies on: ggthemes, harrypotter, oompaBase, palr, pals, scico,  #
#   viridisLite). The app itself only needs shiny + bslib.                     #
################################################################################
###############                  DIAS Jean-Yves                  ###############

library(paletteer)
library(wesanderson)
source(file.path("app", "cvd.R"))  # simulate_cvd(), min_de()

out_dir <- file.path("app", "data")
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

N_MAX <- 30  # maximum number of colours offered in the app for continuous palettes

hex7 <- function(x) toupper(substr(as.character(x), 1, 7))

# ---- 1. Named colours ---------------------------------------------------------
rgbm <- t(col2rgb(colors()))
colors_df <- data.frame(
  name = colors(),
  R = rgbm[, 1], G = rgbm[, 2], B = rgbm[, 3],
  HEX = rgb(rgbm[, 1], rgbm[, 2], rgbm[, 3], maxColorValue = 255),
  stringsAsFactors = FALSE
)
saveRDS(colors_df, file.path(out_dir, "colors.rds"), compress = "gzip")

# ---- 2. Palettes ---------------------------------------------------------------
meta <- list()
cols <- list()

add_pal <- function(id, package, palette, source, type, kind, max_n, values) {
  meta[[length(meta) + 1]] <<- data.frame(
    id = id, package = package, palette = palette, source = source,
    type = type, kind = kind, max_n = max_n, stringsAsFactors = FALSE
  )
  cols[[id]] <<- values
}

safe <- function(expr) tryCatch(expr, error = function(e) NULL)

# 2a. Continuous palettes from paletteer (incl. grDevices rainbow, heat.colors...)
for (i in seq_len(nrow(palettes_c_names))) {
  pk <- palettes_c_names$package[i]; pl <- palettes_c_names$palette[i]
  id <- paste0(pk, "::", pl)
  # some palettes cannot be generated for every n (e.g. n = 1): stored as character(0)
  v <- lapply(seq_len(N_MAX), function(n) {
    x <- safe(hex7(paletteer_c(id, n))); if (is.null(x)) character(0) else x
  })
  if (all(lengths(v) == 0)) { message("skip ", id); next }
  add_pal(id, pk, pl, "paletteer_c", "continuous", palettes_c_names$type[i], N_MAX, v)
}

# 2b. Discrete palettes from paletteer: fixed set of colours
for (i in seq_len(nrow(palettes_d_names))) {
  pk <- palettes_d_names$package[i]; pl <- palettes_d_names$palette[i]
  id <- paste0(pk, "::", pl)
  v <- safe(hex7(paletteer_d(id)))
  if (is.null(v)) { message("skip ", id); next }
  add_pal(id, pk, pl, "paletteer_d", "discrete", palettes_d_names$type[i], length(v), v)
}

# 2c. Dynamic palettes from paletteer: colours depend on n, up to 'length'
for (i in seq_len(nrow(palettes_dynamic_names))) {
  pk <- palettes_dynamic_names$package[i]; pl <- palettes_dynamic_names$palette[i]
  id <- paste0(pk, "::", pl)
  mx <- palettes_dynamic_names$length[i]
  v <- lapply(seq_len(mx), function(n) safe(hex7(paletteer_dynamic(id, n))))
  if (any(vapply(v, is.null, logical(1)))) { message("skip ", id); next }
  add_pal(id, pk, pl, "paletteer_dynamic", "dynamic", palettes_dynamic_names$type[i], mx, v)
}

# 2d. Wes Anderson palettes used as continuous (interpolated) palettes
for (pl in names(wes_palettes)) {
  id <- paste0("wesanderson::", pl, " (continuous)")
  v <- lapply(seq_len(N_MAX), function(n) hex7(wes_palette(pl, n, type = "continuous")))
  add_pal(id, "wesanderson", paste(pl, "(continuous)"), "wes_palette", "continuous", "interpolated", N_MAX, v)
}

# 2e. ggplot2 default (hue) palette
gg_color_hue <- function(n) {
  hues <- seq(15, 375, length = n + 1)
  hcl(h = hues, l = 65, c = 100)[1:n]
}
add_pal("ggplot2::default", "ggplot2", "default", "gg_color_hue", "continuous",
        "qualitative", N_MAX, lapply(seq_len(N_MAX), function(n) hex7(gg_color_hue(n))))

# ---- 3. Colour-blind check ----------------------------------------------------
# For each palette and each n: smallest difference (CIEDE2000) between two of its
# colours, with normal vision and in the worst of deuteranopia, protanopia and
# tritanopia. Used by the "colour-blind friendly" filter of the app.
pal_n_cols <- function(id, type, values, n) {
  if (type == "discrete") utils::head(values, n) else values[[min(n, length(values))]]
}
cvd_check <- lapply(names(cols), function(id) {
  m <- meta[[which(vapply(meta, function(x) x$id, "") == id)]]
  res <- matrix(NA_real_, 2, N_MAX, dimnames = list(c("normal", "cvd"), NULL))
  for (n in 2:N_MAX) {
    v <- pal_n_cols(id, m$type, cols[[id]], n)
    if (length(unique(v)) < 2) next
    res["normal", n] <- min_de(v)
    res["cvd", n] <- min(vapply(c("deuteranopia", "protanopia", "tritanopia"),
                                function(t) min_de(simulate_cvd(v, t)), 0))
  }
  round(res, 1)
})
names(cvd_check) <- names(cols)

meta <- do.call(rbind, meta)
meta <- meta[order(tolower(meta$package), tolower(meta$palette)), ]
rownames(meta) <- NULL
saveRDS(list(meta = meta, cols = cols, n_max = N_MAX, cvd_check = cvd_check),
        file.path(out_dir, "palettes.rds"), compress = "gzip")

message(nrow(colors_df), " colours, ", nrow(meta), " palettes")
