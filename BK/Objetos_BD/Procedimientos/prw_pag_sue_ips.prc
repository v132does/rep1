CREATE OR REPLACE PROCEDURE IT.PRW_PAG_SUE_IPS(
    p_nro_cta_debito   IN VARCHAR2,
    p_nro_doc_deb      IN VARCHAR2,
    p_nro_cta_credito  IN VARCHAR2,
    p_nro_doc_cre      IN VARCHAR2,
    p_importe          IN NUMBER,
    p_tip_operacion    IN VARCHAR2,
    p_nro_operacion    IN NUMBER,
    p_modo             IN VARCHAR2,
    p_nro_lote         IN NUMBER,
    p_resultado        OUT CLOB
) AS
BEGIN
    -- Llamamos a la función real `fuw_pag_sue_ips`
    p_resultado := IT.fuw_pag_sue_ips(
        p_nro_cta_debito, p_nro_doc_deb, p_nro_cta_credito,
        p_nro_doc_cre, p_importe, p_tip_operacion,
        p_nro_operacion, p_modo, p_nro_lote
    );
END PRW_PAG_SUE_IPS;