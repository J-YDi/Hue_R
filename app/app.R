################################################################################
#                     Hue R - colors & palettes codes in R                    #
#      Shiny app (Shinylive-ready): named colours and palettes of R with       #
#                         their RGB and HEX codes                              #
################################################################################
###############                  DIAS Jean-Yves                  ###############

library(shiny)
library(bslib)
source("cvd.R")  # colour vision deficiency simulation + CIEDE2000

# ---- Data (pre-computed by data-raw/build_data.R) ----------------------------
colors_df <- readRDS("data/colors.rds")
pal       <- readRDS("data/palettes.rds")
pal_meta  <- pal$meta
pal_cols  <- pal$cols
cvd_check <- pal$cvd_check  # smallest ΔE2000, normal vision / worst colour blindness
N_MAX     <- pal$n_max
PKGS      <- sort(unique(pal_meta$package))
PKGS      <- PKGS[order(tolower(PKGS))]
DEFAULT_PKGS <- c("ggplot2", "grDevices", "RColorBrewer", "viridis", "wesanderson")

ROWS_PER_BLOCK   <- 50   # colours tab: rows per column block (as in the PDF)
BLOCKS_PER_PAGE  <- 5    # palettes tab: column blocks per page (as in the PDF)
PAL_ROWS_BLOCK   <- 60   # palettes tab: max rows in one block (4 palettes of 15)

# ---- Helpers -----------------------------------------------------------------
# black or white text depending on the background luminance
text_col <- function(hex) {
  m <- grDevices::col2rgb(hex) / 255
  lum <- 0.299 * m[1, ] + 0.587 * m[2, ] + 0.114 * m[3, ]
  ifelse(lum > 0.5, "#000000", "#FFFFFF")
}

hex_to_rgb <- function(hex) {
  m <- grDevices::col2rgb(hex)
  data.frame(R = m[1, ], G = m[2, ], B = m[3, ])
}

# colours of palette `id` for `n` colours (discrete palettes: at most their size)
get_pal <- function(id, n) {
  m <- pal_meta[pal_meta$id == id, ]
  v <- pal_cols[[id]]
  if (m$type == "discrete") return(utils::head(v, n))
  v[[min(n, m$max_n)]]
}

# R code that reproduces the palette
pal_code <- function(id, n) {
  m <- pal_meta[pal_meta$id == id, ]
  switch(m$source,
    paletteer_c       = sprintf('paletteer::paletteer_c("%s", n = %d)', id, n),
    paletteer_d       = sprintf('paletteer::paletteer_d("%s")', id),
    paletteer_dynamic = sprintf('paletteer::paletteer_dynamic("%s", n = %d)', id, min(n, m$max_n)),
    wes_palette       = sprintf('wesanderson::wes_palette("%s", %d, type = "continuous")',
                                sub(" \\(continuous\\)$", "", m$palette), n),
    gg_color_hue      = sprintf('hcl(h = seq(15, 375, length = %d + 1), l = 65, c = 100)[1:%d]', n, n)
  )
}

# parse "#4682B4", "4682b4", "#48b" or "70, 130, 180" -> "#RRGGBB" (or NULL)
parse_colour <- function(x) {
  x <- trimws(x)
  if (!nzchar(x)) return(NULL)
  nums <- suppressWarnings(as.numeric(strsplit(x, "[,; ]+")[[1]]))
  if (length(nums) == 3 && !anyNA(nums) && all(nums >= 0 & nums <= 255))
    return(grDevices::rgb(nums[1], nums[2], nums[3], maxColorValue = 255))
  h <- toupper(sub("^#", "", x))
  if (grepl("^[0-9A-F]{3}$", h)) h <- paste(rep(strsplit(h, "")[[1]], each = 2), collapse = "")
  if (grepl("^[0-9A-F]{6}$", h)) return(paste0("#", h))
  if (tolower(x) %in% colors_df$name) return(colors_df$HEX[colors_df$name == tolower(x)])
  NULL
}

# nearest named colours (distance in CIE Lab, closer to perceived difference)
colors_lab <- grDevices::convertColor(as.matrix(colors_df[, c("R", "G", "B")]) / 255,
                                      from = "sRGB", to = "Lab")
nearest_colours <- function(hex, k = 5) {
  lab <- grDevices::convertColor(t(grDevices::col2rgb(hex)) / 255, from = "sRGB", to = "Lab")
  d <- sqrt(colSums((t(colors_lab) - as.numeric(lab))^2))
  o <- order(d)[seq_len(k)]
  data.frame(colors_df[o, ], dE = round(d[o], 1))
}

copy_btn <- function(text, label = "Copy") {
  tags$button(class = "btn btn-sm btn-outline-secondary copy-btn",
              `data-copy` = text, type = "button", label)
}

# one row of a sheet (name, R, G, B, HEX), coloured by its own HEX
sheet_row <- function(name, hex, cls, attr, show = hex) {
  rgbv <- grDevices::col2rgb(hex)
  tags$tr(
    class = cls, `data-key` = attr,
    style = sprintf("background:%s;color:%s", show, text_col(show)),
    tags$td(class = "nm", name), tags$td(class = "num", rgbv[1]),
    tags$td(class = "num", rgbv[2]), tags$td(class = "num", rgbv[3]),
    tags$td(class = "hx", hex)
  )
}

sheet_block <- function(rows, first_col) {
  tags$table(class = "sheet",
    tags$thead(tags$tr(tags$th(class = "nm", first_col), tags$th("R"),
                       tags$th("G"), tags$th("B"), tags$th("HEX"))),
    tags$tbody(rows))
}

# ---- Colour vision helpers ---------------------------------------------------
# simulated colours of the whole colour sheet, for each type of vision
colour_sim <- lapply(CVD_TYPES, function(t) simulate_cvd(colors_df$HEX, t))
names(colour_sim) <- CVD_TYPES

de_badge <- function(d) {
  if (is.na(d)) return(span(class = "badge text-bg-secondary", "–"))
  cls <- if (d >= 8) "text-bg-success" else if (d >= 5) "text-bg-warning" else "text-bg-danger"
  span(class = paste("badge", cls), title = "Smallest ΔE2000 between two colours",
       sprintf("ΔE %.1f", d))
}

cvd_banner <- function(type) {
  if (type == "normal") return(NULL)
  div(class = "alert alert-info py-1 px-2 mb-2 small",
      tags$b("Simulated view: ", names(CVD_TYPES)[CVD_TYPES == type], ". "),
      "Backgrounds show how the colours are seen; the codes are those of the real colours.")
}

# ---- Colours sheet: built once (static) --------------------------------------
colour_sheet <- local({
  rows <- Map(function(nm, hx) sheet_row(nm, hx, "crow", nm),
              colors_df$name, colors_df$HEX)
  blocks <- split(rows, ceiling(seq_along(rows) / ROWS_PER_BLOCK))
  blocks <- lapply(blocks, sheet_block, first_col = "Color name")
  div(class = "sheet-wrap", blocks)
})

# ---- UI ----------------------------------------------------------------------
js <- "
function copyText(t) {
  if (navigator.clipboard && window.isSecureContext) {
    navigator.clipboard.writeText(t).catch(function(){ fallbackCopy(t); });
  } else { fallbackCopy(t); }
}
function fallbackCopy(t) {
  var ta = document.createElement('textarea'); ta.value = t;
  document.body.appendChild(ta); ta.select();
  try { document.execCommand('copy'); } catch(e) {}
  document.body.removeChild(ta);
}
$(document).on('click', '.copy-btn', function() {
  var b = $(this), old = b.text();
  copyText(b.attr('data-copy'));
  b.text('Copied!'); setTimeout(function(){ b.text(old); }, 1200);
});
$(document).on('click', 'tr.crow', function() {
  Shiny.setInputValue('colour_click', $(this).attr('data-key'), {priority: 'event'});
});
$(document).on('click', 'tr.prow', function() {
  Shiny.setInputValue('pal_click', $(this).attr('data-key'), {priority: 'event'});
});
$(document).on('click', '.near-item', function() {
  Shiny.setInputValue('colour_click', $(this).attr('data-key'), {priority: 'event'});
});
// recolour the colour sheet with simulated colours (same order as the rows)
Shiny.addCustomMessageHandler('recolour', function(m) {
  $('tr.crow').each(function(i) {
    this.style.background = m.bg[i]; this.style.color = m.fg[i];
  });
});
// highlight rows of a colour / palette and scroll to the first one
Shiny.addCustomMessageHandler('highlight', function(m) {
  var tries = 0;
  (function go() {
    $('tr.' + m.cls).removeClass('hl');
    var rows = $('tr.' + m.cls).filter(function(){ return $(this).attr('data-key') === m.key; });
    if (rows.length === 0) { if (tries++ < 20) setTimeout(go, 100); return; }
    rows.addClass('hl');
    rows[0].scrollIntoView({behavior: 'smooth', block: 'center', inline: 'center'});
  })();
});
"

css <- "
.sheet-wrap { display:flex; flex-wrap:wrap; align-items:flex-start; gap:0; }
.sheet-wrap > .sheet { margin:0 -1px -1px 0; }
.sheet { border-collapse:collapse; font-family:Calibri, Carlito, 'Segoe UI', Arial, sans-serif;
         font-size:12px; line-height:1.15; }
.sheet th, .sheet td { border:1px solid #555; padding:1px 4px; white-space:nowrap; }
.sheet th { background:#fff; color:#000; font-weight:bold; font-style:italic; text-align:left; }
.sheet td.num { text-align:right; min-width:24px; }
.sheet td.nm { min-width:128px; }
.colours .sheet td.nm { min-width:118px; }
.palettes .sheet td.nm { min-width:200px; max-width:260px; overflow:hidden; text-overflow:ellipsis; }
.sheet td.hx { font-family:Calibri, Carlito, Arial, sans-serif; }
.sheet tbody tr { cursor:pointer; }
.sheet tbody tr:hover td { outline:1px solid #000; }
.sheet tr.hl td { outline:3px solid #000 !important; outline-offset:-2px; font-weight:bold;
                  animation: blink 1s ease-in-out 2; }
@keyframes blink { 50% { outline-color:#ff00ff; } }
.sheet-note { font-size:12px; text-align:center; border:1px solid #555; border-bottom:0;
              padding:2px; font-family:Calibri, Carlito, Arial, sans-serif; }
.big-swatch { height:90px; border-radius:6px; border:1px solid #888; display:flex;
              align-items:center; justify-content:center; font-weight:bold; font-size:18px; }
.codes { width:100%; font-size:14px; margin-top:8px; }
.codes td { padding:3px 4px; vertical-align:middle; }
.codes td:first-child { font-weight:bold; width:42px; }
.codes code { font-size:13px; }
.near-item { display:flex; align-items:center; gap:8px; cursor:pointer; padding:2px 4px;
             border-radius:4px; font-size:13px; }
.near-item:hover { background:#eee; }
.near-sw { width:28px; height:18px; border:1px solid #888; border-radius:3px; flex:none; }
.strip { display:flex; height:46px; border:1px solid #888; border-radius:6px; overflow:hidden; }
.strip div { flex:1; }
.pal-table { font-size:13px; width:100%; border-collapse:collapse; margin-top:8px; }
.pal-table td { padding:1px 6px; border:1px solid #ccc; }
.pal-table td.sw { width:26px; }
.rcode { font-size:12px; white-space:pre-wrap; word-break:break-all; background:#f6f6f6;
         padding:6px; border-radius:4px; }
.cvd-row { display:flex; align-items:center; gap:6px; font-size:12px; margin:2px 0; }
.cvd-row .lab { width:92px; flex:none; }
.cvd-row .mini { flex:1; display:flex; height:16px; border:1px solid #999; border-radius:3px; overflow:hidden; }
.cvd-row .mini div { flex:1; }
.cvd-grid { display:grid; grid-template-columns:repeat(4, 1fr); gap:4px; margin-top:8px; }
.cvd-grid div { font-size:10px; text-align:center; }
.cvd-grid .sw { height:26px; border:1px solid #999; border-radius:3px; }
.verdict { font-weight:bold; font-size:13px; margin:6px 0 2px; }
.pkg-box { max-height:220px; overflow-y:auto; border:1px solid #dee2e6; border-radius:4px;
           padding:4px 8px; margin-bottom:12px; font-size:13px; }
.pkg-box .form-group { margin-bottom:0; }
.pkg-box .checkbox { margin:0; }
.pager { display:flex; align-items:center; gap:8px; margin-bottom:8px; flex-wrap:wrap; }
.bslib-sidebar-layout > .sidebar { font-size:14px; }
"

ui <- page_sidebar(
  title = tags$div(
    tags$img(src = "logo.png", height = "40px", style = "vertical-align: middle; margin-right: 10px;"),
    "Hue R - Colors & palettes codes in R",
    style = "display: flex; align-items: center;"
  ),
  # Bootstrap 5 theme without Google font: bootswatch presets download a font
  # at start-up, which fails under webR/Shinylive.
  theme = bs_theme(version = 5),
  tags$head(tags$style(HTML(css)), tags$script(HTML(js))),

  sidebar = sidebar(
    width = 320,

    # ---------------- Colour vision (both tabs) ----------------
    selectInput("cvd", tags$b("Simulate colour vision"), choices = CVD_TYPES),
    hr(),

    # ---------------- Colors controls ----------------
    conditionalPanel(
      "input.main_tabs == 'Colors'",
      h6("Search", style = "font-weight: bold; margin-bottom: 10px; color: #333;"),
      selectizeInput("colour_search", tags$b("Colour name"),
                     choices = c("", colors_df$name), selected = "",
                     options = list(placeholder = "e.g. steelblue", maxOptions = 1000)),
      uiOutput("colour_result"),
      hr(),
      h6("Reverse search", style = "font-weight: bold; margin-bottom: 10px; color: #333;"),
      textInput("hex_search", tags$b("Closest named colours"),
                placeholder = "#4682B4  or  70, 130, 180"),
      uiOutput("near_result"),
      hr(),
      p(class = "text-muted small",
        "Click any row of the sheet to get its codes. ",
        length(colors_df$name), " named colours from ", code("colors()"),
        ", usable in base R and ggplot2.")
    ),

    # ---------------- Palettes controls ----------------
    conditionalPanel(
      "input.main_tabs == 'Palettes'",
      numericInput("n", tags$b(sprintf("Number of colours (1 to %d)", N_MAX)),
                   value = 15, min = 1, max = N_MAX, step = 1),
      checkboxInput("strict", "Strict: only palettes with at least this number of colours",
                    value = FALSE),
      hr(),
      h6("Search", style = "font-weight: bold; margin-bottom: 10px; color: #333;"),
      selectizeInput("pal_search", tags$b("Palette"), choices = NULL,
                     options = list(placeholder = "e.g. RColorBrewer::Set1")),
      uiOutput("pal_result"),
      hr(),
      h6("Filters", style = "font-weight: bold; margin-bottom: 10px; color: #333;"),
      checkboxGroupInput("pal_type", tags$b("Type"), inline = TRUE,
                         choices = c("continuous", "discrete", "dynamic"),
                         selected = c("continuous", "discrete", "dynamic")),
      div(style = "display:flex; align-items:center; justify-content:space-between; margin-bottom:4px;",
          tags$b("Packages"),
          actionButton("toggle_all_pkg", "Select all / none", class = "btn-sm btn-outline-primary",
                       style = "font-size: 11px; padding: 4px 8px;")),
      div(class = "pkg-box",
          checkboxGroupInput("pal_pkg", NULL, choices = PKGS, selected = DEFAULT_PKGS)),
      sliderInput("cvd_min", tags$b("Colour-blind friendly: minimum ΔE"),
                  min = 0, max = 20, value = 0, step = 1),
      p(class = "text-muted small", style = "margin-top:-8px",
        "Keeps palettes whose colours stay distinct (smallest ΔE2000 between two colours) ",
        "with deuteranopia, protanopia and tritanopia. 0 = no filter, 8 = distinct."),
      p(class = "text-muted small",
        "Discrete palettes have a fixed number of colours: when you ask for more, ",
        "all their colours are shown.")
    ),

    hr(),

    tags$footer(
      tags$small(
        "© 2026 - Jean-Yves Dias",
        tags$br(),
        tags$a("Hue R on GitHub", href = "https://github.com/J-YDi/Hue_R",
               target = "_blank", style = "color: #666;")
      ),
      style = "text-align: center; color: #666; font-size: 10px; margin-top: 20px; padding-top: 10px;"
    )
  ),

  navset_card_tab(
    id = "main_tabs",
    full_screen = TRUE,
    nav_panel(
      "Colors",
      uiOutput("cvd_banner_c"),
      div(class = "colours", colour_sheet)
    ),
    nav_panel(
      "Palettes",
      uiOutput("cvd_banner_p"),
      div(class = "pager",
          actionButton("prev_page", "◀", class = "btn-sm btn-outline-primary"),
          uiOutput("page_label", inline = TRUE),
          actionButton("next_page", "▶", class = "btn-sm btn-outline-primary")),
      div(class = "palettes", uiOutput("pal_sheet"))
    )
  )
)

# ---- Server ------------------------------------------------------------------
server <- function(input, output, session) {

  # =============== Colour vision ===============
  output$cvd_banner_c <- renderUI(cvd_banner(input$cvd))
  output$cvd_banner_p <- renderUI(cvd_banner(input$cvd))
  observeEvent(input$cvd, {
    bg <- colour_sim[[input$cvd]]
    session$sendCustomMessage("recolour", list(bg = bg, fg = text_col(bg)))
  }, ignoreInit = TRUE)

  # =============== Colours ===============
  observeEvent(input$colour_click, {
    updateSelectizeInput(session, "colour_search", selected = input$colour_click)
  })

  observeEvent(input$colour_search, {
    req(input$colour_search)
    session$sendCustomMessage("highlight", list(cls = "crow", key = input$colour_search))
  })

  output$colour_result <- renderUI({
    req(input$colour_search)
    r <- colors_df[colors_df$name == input$colour_search, ]
    req(nrow(r) == 1)
    rgb_txt <- sprintf("%d, %d, %d", r$R, r$G, r$B)
    show <- simulate_cvd(r$HEX, input$cvd)
    tagList(
      div(class = "big-swatch",
          style = sprintf("background:%s;color:%s", show, text_col(show)), r$name),
      tags$table(class = "codes",
        tags$tr(tags$td("RGB"), tags$td(code(rgb_txt)), tags$td(copy_btn(rgb_txt))),
        tags$tr(tags$td("HEX"), tags$td(code(r$HEX)), tags$td(copy_btn(r$HEX))),
        tags$tr(tags$td("R"), tags$td(code(sprintf('"%s"', r$name))),
                tags$td(copy_btn(sprintf('"%s"', r$name))))
      ),
      div(class = "small mt-2", tags$b("Seen with:")),
      div(class = "cvd-grid", lapply(CVD_TYPES, function(t) {
        div(div(class = "sw", style = sprintf("background:%s", simulate_cvd(r$HEX, t))),
            CVD_SHORT[[t]])
      }))
    )
  })

  output$near_result <- renderUI({
    req(nzchar(trimws(input$hex_search)))
    hex <- parse_colour(input$hex_search)
    if (is.null(hex)) return(p(class = "text-danger small", "Not a valid HEX or R, G, B value."))
    nn <- nearest_colours(hex)
    tagList(
      div(class = "near-item", style = "cursor:default",
          div(class = "near-sw", style = sprintf("background:%s", hex)),
          tags$b(hex), span(class = "text-muted", "(your colour)")),
      lapply(seq_len(nrow(nn)), function(i) {
        div(class = "near-item", `data-key` = nn$name[i],
            div(class = "near-sw", style = sprintf("background:%s", nn$HEX[i])),
            span(nn$name[i]), span(class = "text-muted", nn$HEX[i]),
            span(class = "text-muted ms-auto", if (nn$dE[i] == 0) "exact" else paste0("ΔE ", nn$dE[i])))
      })
    )
  })

  # =============== Palettes ===============
  updateSelectizeInput(session, "pal_search", choices = c("", pal_meta$id),
                       selected = "", server = TRUE)

  n_val <- reactive({
    n <- suppressWarnings(as.integer(input$n))
    if (length(n) != 1 || is.na(n)) n <- 15L
    max(1L, min(N_MAX, n))
  }) |> debounce(300)

  pal_filtered <- reactive({
    m <- pal_meta[pal_meta$type %in% input$pal_type, ]
    m <- m[m$package %in% input$pal_pkg, ]
    if (isTRUE(input$strict)) m <- m[m$max_n >= n_val(), ]
    if (isTRUE(input$cvd_min > 0)) {
      n <- max(2L, n_val())
      d <- vapply(m$id, function(id) cvd_check[[id]]["cvd", n], 0)
      m <- m[!is.na(d) & d >= input$cvd_min, ]
    }
    m
  })

  # pages: blocks of whole palettes (<= PAL_ROWS_BLOCK rows), BLOCKS_PER_PAGE per page
  pal_layout <- reactive({
    m <- pal_filtered(); n <- n_val()
    if (!nrow(m)) return(list(page = integer(0), block = integer(0), ids = character(0)))
    nrows <- vapply(m$id, function(id) max(1L, length(get_pal(id, n))), integer(1))
    block <- integer(length(nrows)); b <- 1L; used <- 0L
    for (i in seq_along(nrows)) {
      if (used > 0 && used + nrows[i] > PAL_ROWS_BLOCK) { b <- b + 1L; used <- 0L }
      block[i] <- b; used <- used + nrows[i]
    }
    list(ids = m$id, block = block, page = ceiling(block / BLOCKS_PER_PAGE))
  })

  n_pages <- reactive(max(1L, pal_layout()$page))
  page <- reactiveVal(1L)
  # priority > 0: runs before the "focus" observer when both are triggered together
  observeEvent(list(input$pal_type, input$pal_pkg, input$strict), page(1L), ignoreInit = TRUE,
               ignoreNULL = FALSE, priority = 10)
  observeEvent(n_pages(), if (page() > n_pages()) page(n_pages()))
  observeEvent(input$prev_page, page(max(1L, page() - 1L)))
  observeEvent(input$next_page, page(min(n_pages(), page() + 1L)))

  output$page_label <- renderUI({
    span(sprintf("Page %d / %d  –  %d palettes", page(), n_pages(), length(pal_layout()$ids)))
  })

  output$pal_sheet <- renderUI({
    L <- pal_layout(); n <- n_val()
    sel_id <- input$pal_search
    cvd <- input$cvd
    if (!length(L$ids)) return(p("No palette matches these filters."))
    sel <- L$page == page()
    ids <- L$ids[sel]; blk <- L$block[sel]
    blocks <- lapply(split(ids, blk), function(bids) {
      rows <- unlist(lapply(bids, function(id) {
        v <- get_pal(id, n)
        if (!length(v)) return(list(tags$tr(class = "prow", `data-key` = id,
                                            tags$td(class = "nm", id),
                                            tags$td(colspan = 4, "not available for this n"))))
        cls <- if (identical(id, sel_id)) "prow hl" else "prow"
        show <- simulate_cvd(v, cvd)
        Map(function(hx, sh) sheet_row(id, hx, cls, id, show = sh), v, show)
      }), recursive = FALSE)
      sheet_block(rows, "package::palette")
    })
    tagList(
      div(class = "sheet-note",
          "You will need: library(paletteer), library(RColorBrewer) and library(wesanderson) ",
          "to use these palettes, see their respective documentation for usage"),
      div(class = "sheet-wrap", blocks))
  })

  # select all packages, or none if they are all selected
  observeEvent(input$toggle_all_pkg, {
    sel <- if (length(input$pal_pkg) == length(PKGS)) character(0) else PKGS
    updateCheckboxGroupInput(session, "pal_pkg", selected = sel)
  })

  # selecting a palette: show it, make it visible in the sheet and highlight it
  focus <- reactiveVal(NULL)

  observeEvent(input$pal_click, {
    updateSelectizeInput(session, "pal_search", choices = c("", pal_meta$id),
                         selected = input$pal_click, server = TRUE)
  })

  observeEvent(input$pal_search, {
    req(input$pal_search %in% pal_meta$id)
    m <- pal_meta[pal_meta$id == input$pal_search, ]
    if (!(m$type %in% input$pal_type))
      updateCheckboxGroupInput(session, "pal_type", selected = c(input$pal_type, m$type))
    if (isTRUE(input$strict) && m$max_n < n_val()) {
      updateCheckboxInput(session, "strict", value = FALSE)
      showNotification(sprintf("Strict mode turned off: %s has only %d colours.", m$id, m$max_n),
                       type = "warning", duration = 6)
    }
    if (!(m$package %in% input$pal_pkg))
      updateCheckboxGroupInput(session, "pal_pkg", selected = c(input$pal_pkg, m$package))
    focus(m$id)
  })

  observe({
    id <- focus(); req(id)
    L <- pal_layout()
    i <- match(id, L$ids)
    req(!is.na(i))            # waits until the filters include the palette
    isolate({
      if (page() != L$page[i]) page(L$page[i])
      session$sendCustomMessage("highlight", list(cls = "prow", key = id))
      focus(NULL)
    })
  })

  output$pal_result <- renderUI({
    req(input$pal_search %in% pal_meta$id)
    id <- input$pal_search; n <- n_val()
    m <- pal_meta[pal_meta$id == id, ]
    v <- get_pal(id, n)
    if (!length(v)) return(p(class = "text-danger small",
                             "This palette cannot be generated with n = ", n, "."))
    d <- hex_to_rgb(v)
    vec_txt <- paste0("c(", paste0('"', v, '"', collapse = ", "), ")")
    note <- if (length(v) < n)
      div(class = "alert alert-warning py-1 px-2 small mt-2 mb-0",
          sprintf("This %s palette has only %d colours: all of them are shown.", m$type, length(v)))
    # colour vision check: smallest ΔE2000 between two colours for each vision
    de <- vapply(CVD_TYPES, function(t) min_de(simulate_cvd(v, t)), 0)
    names(de) <- CVD_TYPES
    worst <- min(de[c("deuteranopia", "protanopia", "tritanopia")])
    verdict <- if (is.na(worst)) NULL else if (worst >= 8)
      div(class = "verdict text-success", "✔ Colour-blind friendly") else if (worst >= 5)
      div(class = "verdict text-warning", "⚠ Use with care for colour-blind readers") else
      div(class = "verdict text-danger", "✖ Not colour-blind friendly")
    vision_check <- tagList(
      div(class = "mt-3 small", tags$b("Colour vision check")),
      verdict,
      lapply(seq_along(CVD_TYPES), function(i) {
        t <- CVD_TYPES[[i]]
        div(class = "cvd-row",
            span(class = "lab", CVD_SHORT[[t]]),
            div(class = "mini", lapply(simulate_cvd(v, t), function(h) div(style = sprintf("background:%s", h)))),
            de_badge(de[[t]]))
      }),
      p(class = "text-muted small mt-1",
        "ΔE = smallest difference (CIEDE2000) between two colours of the palette: ",
        "≥ 8 distinct, 5–8 close, < 5 hard to tell apart. ",
        if (!is.na(de[["normal"]]) && de[["normal"]] < 8)
          "Sequential palettes with many colours have close neighbours even for normal vision: try a smaller n. ",
        "Simulation: Machado et al. (2009).")
    )
    show <- simulate_cvd(v, input$cvd)
    tagList(
      div(class = "strip", lapply(show, function(h) div(style = sprintf("background:%s", h), title = h))),
      div(class = "small text-muted mt-1",
          sprintf("%s palette – %s – %d colour%s", m$type, m$kind,
                  length(v), if (length(v) > 1) "s" else "")),
      note,
      tags$table(class = "pal-table",
        tags$tr(tags$th(""), tags$th("R"), tags$th("G"), tags$th("B"), tags$th("HEX")),
        lapply(seq_along(v), function(i) tags$tr(
          tags$td(class = "sw", style = sprintf("background:%s", v[i])),
          tags$td(d$R[i]), tags$td(d$G[i]), tags$td(d$B[i]), tags$td(code(v[i]))))),
      div(class = "mt-2 d-flex gap-2",
          copy_btn(vec_txt, "Copy HEX vector"),
          copy_btn(paste(sprintf("%d, %d, %d", d$R, d$G, d$B), collapse = "\n"), "Copy RGB")),
      div(class = "mt-2 small", tags$b("Same colours in R:")),
      div(class = "rcode", pal_code(id, n), copy_btn(pal_code(id, n))),
      vision_check
    )
  })
}

shinyApp(ui, server)
