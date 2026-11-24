ALTER TABLE IT.AH_CTA_CERTIFICADOS 
      ADD (cod_isin VARCHAR2(12));
COMMENT ON COLUMN IT.AH_CTA_CERTIFICADOS.cod_isin 
    IS 'Código ISIN BCP del certificado financiero.';
