ALTER TABLE it.ah_cta_plazos
  ADD (
        fec_ult_extracto  DATE,
        nro_folio         NUMBER(7),
        fre_extracto      VARCHAR2(1) default 'M',
        sal_ult_extracto  NUMBER(18,2)
      );
COMMENT ON COLUMN ah_cta_plazos.fec_ult_extracto IS 'Fecha de Ultimo Extracto.';
COMMENT ON COLUMN ah_cta_plazos.nro_folio IS 'Ultimo Número de Folio del extracto impreso.';
COMMENT ON COLUMN ah_cta_plazos.fre_extracto IS 'Frecuencia de Extracto (D=Diaria /S=Semanal/Q=Quincenal/M=Mensual).';
COMMENT ON COLUMN ah_cta_plazos.sal_ult_extracto IS 'Saldo de Ultimo Extracto.';
