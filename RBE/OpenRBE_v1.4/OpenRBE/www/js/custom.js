/* =============================================================================
   OpenRBE - JavaScript personnalisé
   ITIE Sénégal - www/js/custom.js
   ============================================================================= */

$(document).ready(function () {

  // ── Indicateur de chargement Shiny ─────────────────────────────────────────
  $(document).on("shiny:busy", function () {
    if (!$("#openrbe-spinner").length) {
      $("body").append(
        '<div id="openrbe-spinner" class="loading-overlay">' +
          '<div class="spinner"></div>' +
        '</div>'
      );
    }
    $("#openrbe-spinner").fadeIn(150);
  });
  $(document).on("shiny:idle", function () {
    $("#openrbe-spinner").fadeOut(250, function () {
      $(this).remove();
    });
  });

  // ── Tooltip sur les KPI cards ───────────────────────────────────────────────
  $('[data-toggle="tooltip"]').tooltip();

  // ── Smooth scroll pour ancres internes ─────────────────────────────────────
  $(document).on("click", 'a[href^="#"]', function (e) {
    var target = $($(this).attr("href"));
    if (target.length) {
      e.preventDefault();
      $("html, body").animate({ scrollTop: target.offset().top - 80 }, 350);
    }
  });

  // ── Animation d'entrée des cartes KPI ──────────────────────────────────────
  function animateKPI() {
    $(".kpi-card").each(function (i) {
      var $card = $(this);
      setTimeout(function () {
        $card.css({ opacity: 0, transform: "translateY(14px)" })
          .animate({ opacity: 1 }, {
            duration: 400,
            step: function (now) {
              var ty = 14 * (1 - now);
              $(this).css("transform", "translateY(" + ty + "px)");
            }
          });
      }, i * 80);
    });
  }

  // Déclencher à chaque changement d'onglet
  $(document).on("shown.bs.tab", function () {
    animateKPI();
  });

  // ── Raccourcis clavier ──────────────────────────────────────────────────────
  $(document).on("keydown", function (e) {
    // Ctrl + 1-5 : navigation entre onglets Shiny natifs
    if (e.ctrlKey && e.key >= "1" && e.key <= "5") {
      e.preventDefault();
      var tabs = $(".nav-tabs .nav-link");
      var idx  = parseInt(e.key) - 1;
      if (tabs.eq(idx).length) tabs.eq(idx).trigger("click");
    }
  });

  // ── Copier au clic sur une cellule de tableau ────────────────────────────────
  $(document).on("click", "table.dataTable tbody td", function () {
    var text = $(this).text().trim();
    if (text && text !== "—" && navigator.clipboard) {
      navigator.clipboard.writeText(text).then(function () {
        // Flash visuel discret
        var $cell = $(this);
        $cell.css("background-color", "#E8F5EE");
        setTimeout(function () { $cell.css("background-color", ""); }, 600);
      }.bind(this));
    }
  });

  // ── Afficher/masquer le panneau sidebar sur mobile ──────────────────────────
  $(document).on("click", "#sidebar-toggle", function () {
    $("#openrbe-sidebar").toggleClass("sidebar-hidden");
    $(this).find("i").toggleClass("fa-bars fa-times");
  });

  // ── Redimensionner les graphiques Plotly/Highcharts à la fenêtre ────────────
  $(window).on("resize", function () {
    $(".plotly .js-plotly-plot").each(function () {
      if (window.Plotly) {
        Plotly.Plots.resize(this);
      }
    });
  });

  // ── Message de bienvenue console ───────────────────────────────────────────
  console.log(
    "%cOpenRBE — Open Registre des Bénéficiaires Effectifs\n" +
    "%cITIE Sénégal | Plateforme de transparence extractive v1.0",
    "color:#008C45;font-size:16px;font-weight:bold;",
    "color:#666;font-size:12px;"
  );

});

// ── Utilitaire : formater un nombre ────────────────────────────────────────────
function formatNumber(n) {
  if (isNaN(n)) return "—";
  return n.toLocaleString("fr-FR");
}

// ── Utilitaire : exporter tableau en CSV côté client ───────────────────────────
function exportTableCSV(tableId, filename) {
  var rows = [];
  $("#" + tableId + " thead tr").each(function () {
    var headers = [];
    $(this).find("th").each(function () { headers.push($(this).text().trim()); });
    rows.push(headers.join(";"));
  });
  $("#" + tableId + " tbody tr").each(function () {
    var cells = [];
    $(this).find("td").each(function () { cells.push($(this).text().trim()); });
    rows.push(cells.join(";"));
  });
  var blob = new Blob(["\uFEFF" + rows.join("\n")], { type: "text/csv;charset=utf-8;" });
  var url  = URL.createObjectURL(blob);
  var a    = document.createElement("a");
  a.href   = url;
  a.download = filename || "export.csv";
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
  URL.revokeObjectURL(url);
}
