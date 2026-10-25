class URLConst {
  static const paCompendium2011URL = "https://pacompendium.com/";
  // Citations for the in-app medical/health calculations. Surfaced on the
  // Sources & References screen (see `sources_screen.dart`) so that users
  // can verify each number we show against its peer-reviewed source.
  static const sourceEnergyIomDriURL =
      "https://nap.nationalacademies.org/catalog/10490";
  // Per-nutrient reference intakes shown on the diary's daily nutrient
  // panel (fibre, iron, calcium, vitamins, etc.) come from this Summary
  // Report, which covers the broader DRI tables — distinct from the
  // energy-specific 2005 catalogue cited above.
  static const sourceNutrientReferenceIomURL =
      "https://www.nationalacademies.org/our-work/summary-report-of-the-dietary-reference-intakes";

  static const sourceMacrosWhoTrs916URL =
      "https://iris.who.int/handle/10665/42665";
  static const sourceActivityCompendium2024URL =
      "https://pubmed.ncbi.nlm.nih.gov/38242596/";
  static const sourceEnergyCompensationCareau2021URL =
      "https://pubmed.ncbi.nlm.nih.gov/34453886/";

  // Wiki page documenting every in-app calculation in full — linked from
  // the calorie-goal transparency screen for people who want the complete
  // derivation including sources.
  static const wikiCalculationsURL =
      "https://github.com/simonoppowa/OpenNutriTracker/wiki/Calculations";
}
