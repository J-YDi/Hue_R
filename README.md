# Hue R

*Who are you, colour?* Find the RGB and HEX codes of every named colour and palette in R.

**App: https://j-ydi.github.io/Hue_R/** — runs entirely in your browser (Shinylive / webR), nothing to install.

## What it does
- **Colors**: the sheet of the 657 named colours of R and ggplot2 (`colors()`), each row coloured by its own colour. Search a colour by name to get its RGB and HEX codes, or use the reverse search: type a HEX or `R, G, B` value to get the closest named colours.
- **Palettes**: choose the number of colours (1 to 30), then browse the sheet of 2,918 palettes (base R, ggplot2 default, paletteer, RColorBrewer, wesanderson…), filtered by package and type. Search a palette by name to get its RGB and HEX codes, copy them as an R vector `c("#…", …)` and get the R code that reproduces them. Discrete palettes have a fixed size: when more colours are requested, all of their colours are shown.

Click any row of a sheet to get its codes.

## Structure
- `app/app.R`: the Shiny app (only needs `shiny` and `bslib`)
- `app/data/`: pre-computed colours and palettes
- `data-raw/build_data.R`: rebuilds `app/data/` (needs `paletteer`, `wesanderson` and the palette packages used by `paletteer`). Run it from the repository root, e.g. after updating `paletteer`.
- `.github/workflows/deploy-shinylive.yml`: exports the app with Shinylive and publishes it on GitHub Pages at each push on `main`.

Run locally: `shiny::runApp("app")`.

The static PDF and Excel versions of the sheets are in [colors_codes_in_R](https://github.com/J-YDi/colors_codes_in_R).

#### DIAS Jean-Yves
