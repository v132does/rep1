CREATE OR REPLACE TRIGGER IT.tb_ge_ing_clientes
  BEFORE INSERT ON "IT"."GE_ING_CLIENTES"
  FOR EACH ROW
DECLARE
  v_es_mig varchar(1);
  --
BEGIN
  SELECT 'S'
    INTO v_es_mig
    FROM ba_personas p
   WHERE p.cod_persona = :new.cod_persona
     AND upper(p.cod_usu_promotor) like 'V_%';
  --Validamos si es un cliente migrado y marcamos
  IF v_es_mig = 'S' then
    :new.estado := 'M';
    :new.observacion    := 'Cliente migrado.';
  END IF;
EXCEPTION
  WHEN no_data_found THEN
    v_es_mig := 'N';
  WHEN too_many_rows THEN
    v_es_mig := 'S';
  WHEN OTHERS THEN
    v_es_mig := 'N';
END;
/
