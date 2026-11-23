################################################################################
#   Hue R - colour vision deficiency simulation and colour differences         #
#   Used by app/app.R and data-raw/build_data.R                                #
################################################################################
###############                  DIAS Jean-Yves                  ###############

# ---- Colour vision deficiency (CVD) simulation --------------------------------
# Machado, Oliveira & Fernandes (2009) matrices, applied in linear RGB:
# complete forms (-anopia) = severity 1, partial forms (-anomaly) = severity 0.6.
# Identical to colorspace::deutan(), protan(), tritan().
CVD_MATRICES <- list(
  protanopia    = matrix(c( 0.152286, 1.052583, -0.204868,  0.114503, 0.786281, 0.099216, -0.003882, -0.048116, 1.051998), 3, byrow = TRUE),
  deuteranopia  = matrix(c( 0.367322, 0.860646, -0.227968,  0.280085, 0.672501, 0.047413, -0.011820,  0.042940, 0.968881), 3, byrow = TRUE),
  tritanopia    = matrix(c( 1.255528, -0.076749, -0.178779, -0.078411, 0.930809, 0.147602,  0.004733,  0.691367, 0.303900), 3, byrow = TRUE),
  protanomaly   = matrix(c( 0.385450, 0.769005, -0.154455,  0.100526, 0.829802, 0.069673, -0.007442, -0.022190, 1.029632), 3, byrow = TRUE),
  deuteranomaly = matrix(c( 0.498864, 0.674741, -0.173604,  0.205199, 0.754872, 0.039929, -0.011131,  0.030969, 0.980162), 3, byrow = TRUE),
  tritanomaly   = matrix(c( 1.104996, -0.046633, -0.058363, -0.032137, 0.971635, 0.060503,  0.001336,  0.317922, 0.680742), 3, byrow = TRUE)
)
CVD_TYPES <- c(
  "Normal vision"                       = "normal",
  "Deuteranopia (no green cones)"       = "deuteranopia",
  "Protanopia (no red cones)"           = "protanopia",
  "Tritanopia (no blue cones)"          = "tritanopia",
  "Deuteranomaly (weak green, partial)" = "deuteranomaly",
  "Protanomaly (weak red, partial)"     = "protanomaly",
  "Tritanomaly (weak blue, partial)"    = "tritanomaly",
  "Achromatopsia (no colour, greyscale)" = "achromatopsia"
)
CVD_SHORT <- c(normal = "Normal", deuteranopia = "Deuteranopia", protanopia = "Protanopia",
               tritanopia = "Tritanopia", deuteranomaly = "Deuteranomaly",
               protanomaly = "Protanomaly", tritanomaly = "Tritanomaly",
               achromatopsia = "Achromatopsia")

srgb_to_lin <- function(x) ifelse(x <= 0.04045, x / 12.92, ((x + 0.055) / 1.055)^2.4)
lin_to_srgb <- function(x) {
  x <- pmin(pmax(x, 0), 1)
  ifelse(x <= 0.0031308, 12.92 * x, 1.055 * x^(1 / 2.4) - 0.055)
}

simulate_cvd <- function(hex, type) {
  if (type == "normal" || !length(hex)) return(hex)
  lin <- srgb_to_lin(grDevices::col2rgb(hex) / 255)          # 3 x n
  out <- if (type == "achromatopsia") {
    y <- colSums(lin * c(0.2126, 0.7152, 0.0722))
    rbind(y, y, y)
  } else CVD_MATRICES[[type]] %*% lin
  s <- lin_to_srgb(out)
  grDevices::rgb(s[1, ], s[2, ], s[3, ])
}

# ---- Colour difference (CIEDE2000) --------------------------------------------
hex_to_lab <- function(hex) {
  grDevices::convertColor(t(grDevices::col2rgb(hex)) / 255, from = "sRGB", to = "Lab")
}
de2000 <- function(lab1, lab2) {
  L1 <- lab1[, 1]; a1 <- lab1[, 2]; b1 <- lab1[, 3]
  L2 <- lab2[, 1]; a2 <- lab2[, 2]; b2 <- lab2[, 3]
  rad <- pi / 180
  C1 <- sqrt(a1^2 + b1^2); C2 <- sqrt(a2^2 + b2^2); Cb <- (C1 + C2) / 2
  G <- 0.5 * (1 - sqrt(Cb^7 / (Cb^7 + 25^7)))
  a1p <- (1 + G) * a1; a2p <- (1 + G) * a2
  C1p <- sqrt(a1p^2 + b1^2); C2p <- sqrt(a2p^2 + b2^2)
  h1p <- (atan2(b1, a1p) / rad) %% 360; h2p <- (atan2(b2, a2p) / rad) %% 360
  dLp <- L2 - L1; dCp <- C2p - C1p
  dh <- h2p - h1p
  dh <- ifelse(C1p * C2p == 0, 0, ifelse(dh > 180, dh - 360, ifelse(dh < -180, dh + 360, dh)))
  dHp <- 2 * sqrt(C1p * C2p) * sin(dh / 2 * rad)
  Lbp <- (L1 + L2) / 2; Cbp <- (C1p + C2p) / 2
  hs <- h1p + h2p
  hbp <- ifelse(C1p * C2p == 0, hs,
                ifelse(abs(h1p - h2p) <= 180, hs / 2,
                       ifelse(hs < 360, (hs + 360) / 2, (hs - 360) / 2)))
  Tt <- 1 - 0.17 * cos((hbp - 30) * rad) + 0.24 * cos(2 * hbp * rad) +
    0.32 * cos((3 * hbp + 6) * rad) - 0.20 * cos((4 * hbp - 63) * rad)
  dTh <- 30 * exp(-((hbp - 275) / 25)^2)
  Rc <- 2 * sqrt(Cbp^7 / (Cbp^7 + 25^7))
  Sl <- 1 + 0.015 * (Lbp - 50)^2 / sqrt(20 + (Lbp - 50)^2)
  Sc <- 1 + 0.045 * Cbp; Sh <- 1 + 0.015 * Cbp * Tt
  Rt <- -sin(2 * dTh * rad) * Rc
  sqrt((dLp / Sl)^2 + (dCp / Sc)^2 + (dHp / Sh)^2 + Rt * (dCp / Sc) * (dHp / Sh))
}

# smallest difference between any two colours of a set (ΔE2000)
min_de <- function(hex) {
  hex <- unique(hex)
  if (length(hex) < 2) return(NA_real_)
  lab <- hex_to_lab(hex)
  pr <- utils::combn(nrow(lab), 2)
  min(de2000(lab[pr[1, ], , drop = FALSE], lab[pr[2, ], , drop = FALSE]))
}
