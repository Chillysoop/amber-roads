-- The Corrund March: the vertical slice region.
-- Rows are odd-r offset rows, west to east. Codes come from terrain.codes.
-- Roads are drawn afterwards as hex lines between consecutive waypoints, so
-- a road is always connected no matter how the base terrain is edited.
return {
    name = "The Corrund March",
    rows = {
        "jjjjjjjjjjjjjddd",
        "jjjjjjjjjjjjdddd",
        "sssjjjjjjjjjdddd",
        "ssssssjjsssssddd",
        "sssssssssssssddd",
        "ssssssssssssssdd",
        "ssssssssssssssdd",
        "sssssssssssssssd",
        "sssssssssssssssd",
        "ssssssssssssssss",
    },
    -- Points of interest, in offset coordinates. Horned House law bans the
    -- slave trade in Corrund; Talonmere and Ashfall look the other way.
    places = {
        { id = "corrund", name = "Corrund", kind = "city", col = 1, row = 5,
          text = "Horned House stone city" },
        { id = "talonmere", name = "Talonmere", kind = "city", col = 14, row = 4,
          text = "Talon brokerage port", slave_market = true },
        { id = "ashfall", name = "Ashfall Wells", kind = "city", col = 6, row = 8,
          text = "Frontier waystation town", slave_market = true },
        { id = "fernwatch", name = "Fernwatch", kind = "waystation", col = 4, row = 2,
          text = "Warden post on the Accord road" },
        { id = "oldfort", name = "Old Accord Fort", kind = "waystation", col = 10, row = 1,
          text = "A half-ruined fort with a cistern" },
        { id = "bitterwell", name = "Bitterwell", kind = "well", col = 9, row = 6,
          text = "A brackish well in the open steppe" },
    },
    -- Each road is a chain of place ids.
    roads = {
        { "corrund", "fernwatch", "oldfort", "talonmere" },
        { "corrund", "ashfall" },
    },
    start = "corrund",
    -- Supply levels on the 10-step scale (1 big surplus, 10 desperate).
    -- Corrund quarries iron and buys amber cheaply from jungle cutters;
    -- Talonmere's brokers ship amber abroad and land sea salt and spice;
    -- Ashfall Wells is cattle-and-hide country that needs everything else.
    markets = {
        corrund = { amber = 1, ironwork = 1, salt = 6, hides = 6, spice = 8 },
        talonmere = { amber = 9, ironwork = 7, salt = 2, hides = 7, spice = 2 },
        ashfall = { amber = 4, ironwork = 9, salt = 5, hides = 1, spice = 7 },
    },
}
