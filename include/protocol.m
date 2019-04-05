# protocol.m: Alerting and Wire Protocol Exporter Specification

AlertProtocol: module
{
    PATH: con "/dis/protocol.dis";

    # Common Alerting Protocol (OASIS CAP v1.2)
    format_cap_xml: fn(hypo: ref Scarp->HypoSolution,
                       mag: ref Scarp->MagnitudeSol,
                       shakemap_summary: string,
                       sender_id: string): string;

    # QuakeML 1.2 XML
    format_quakeml_xml: fn(hypo: ref Scarp->HypoSolution,
                           mag: ref Scarp->MagnitudeSol,
                           picks: list of ref Scarp->PhasePick): string;

    # GeoJSON FeatureCollection
    format_shakemap_geojson: fn(cells: list of ref Scarp->ShakeMapCell,
                                hypo: ref Scarp->HypoSolution): string;
};
