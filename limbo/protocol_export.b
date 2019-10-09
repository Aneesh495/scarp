# protocol_export.b: OASIS CAP, QuakeML, and GeoJSON Serializers in Limbo
implement ProtocolExport;

include "sys.m";
    sys: Sys;

include "scarp.m";
    scarp: Scarp;

include "protocol.m";
    protocol: AlertProtocol;

ProtocolExport: module
{
    PATH: con "/dis/protocol_export.dis";

    init: fn(ctxt: ref Sys->FD, argv: list of string);

    format_cap_xml: fn(hypo: ref Scarp->HypoSolution,
                       mag: ref Scarp->MagnitudeSol,
                       summary: string,
                       sender_id: string): string;

    format_geojson: fn(cells: list of ref Scarp->ShakeMapCell,
                       hypo: ref Scarp->HypoSolution): string;
};

init(nil: ref Sys->FD, nil: list of string)
{
    sys = load Sys Sys->PATH;
}

format_cap_xml(hypo: ref Scarp->HypoSolution,
               mag: ref Scarp->MagnitudeSol,
               summary: string,
               sender_id: string): string
{
    ev_id := (hypo != nil ? hypo.event_id : "EVT_000");
    mw_val := (mag != nil ? mag.mag_mw : 5.0);
    lat_val := (hypo != nil ? hypo.lat : 0.0);
    lon_val := (hypo != nil ? hypo.lon : 0.0);

    xml := "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n";
    xml += "<alert xmlns=\"urn:oasis:names:tc:emergency:cap:1.2\">\n";
    xml += "  <identifier>scarp-alert-" + ev_id + "</identifier>\n";
    xml += "  <sender>" + sender_id + "</sender>\n";
    xml += "  <status>Actual</status>\n";
    xml += "  <msgType>Alert</msgType>\n";
    xml += "  <scope>Public</scope>\n";
    xml += "  <info>\n";
    xml += "    <category>Geo</category>\n";
    xml += "    <event>Earthquake Early Warning</event>\n";
    xml += "    <urgency>Immediate</urgency>\n";
    xml += "    <severity>Severe</severity>\n";
    xml += "    <certainty>Observed</certainty>\n";
    xml += "    <headline>Earthquake Early Warning: M" + sys->sprint("%.1f", mw_val) + "</headline>\n";
    xml += "    <description>" + summary + "</description>\n";
    xml += "    <area>\n";
    xml += "      <areaDesc>Hypocentral Epicenter</areaDesc>\n";
    xml += "      <circle>" + sys->sprint("%.4f,%.4f,50.0", lat_val, lon_val) + "</circle>\n";
    xml += "    </area>\n";
    xml += "  </info>\n";
    xml += "</alert>\n";

    return xml;
}

format_geojson(cells: list of ref Scarp->ShakeMapCell,
               hypo: ref Scarp->HypoSolution): string
{
    json := "{\"type\":\"FeatureCollection\",\"features\":[\n";

    # Add hypocenter feature
    if (hypo != nil) {
        json += "  {\"type\":\"Feature\",\"geometry\":{\"type\":\"Point\",\"coordinates\":[";
        json += sys->sprint("%.4f,%.4f", hypo.lon, hypo.lat);
        json += "]},\"properties\":{\"feature\":\"hypocenter\",\"depth_km\":";
        json += sys->sprint("%.1f", hypo.depth_km);
        json += "}}";
    }

    # Add grid cells
    first := (hypo == nil ? 1 : 0);
    for (cur := cells; cur != nil; cur = tl cur) {
        c := hd cur;
        if (first == 0) json += ",\n";
        first = 0;

        json += "  {\"type\":\"Feature\",\"geometry\":{\"type\":\"Point\",\"coordinates\":[";
        json += sys->sprint("%.4f,%.4f", c.lon, c.lat);
        json += "]},\"properties\":{\"pga_pct_g\":";
        json += sys->sprint("%.2f", c.pga_pct_g);
        json += ",\"pgv_cms\":";
        json += sys->sprint("%.2f", c.pgv_cms);
        json += ",\"mmi\":";
        json += sys->sprint("%.1f", c.mmi);
        json += ",\"tti_s\":";
        json += sys->sprint("%.1f", c.tti_seconds);
        json += "}}";
    }

    json += "\n]}\n";
    return json;
}
