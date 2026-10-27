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
    -- Points of interest, in offset coordinates.
    places = {
        { id = "corrund", name = "Corrund", kind = "city", col = 1, row = 5,
          text = "Horned House stone city" },
        { id = "talonmere", name = "Talonmere", kind = "city", col = 14, row = 4,
          text = "Talon brokerage port" },
        { id = "ashfall", name = "Ashfall Wells", kind = "city", col = 6, row = 8,
          text = "Frontier waystation town" },
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
}
