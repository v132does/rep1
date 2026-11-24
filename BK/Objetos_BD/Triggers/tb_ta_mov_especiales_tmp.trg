CREATE OR REPLACE TRIGGER IT.TB_TA_MOV_ESPECIALES_TMP
  BEFORE INSERT ON TA_MOV_ESPECIALES_TMP
  FOR EACH ROW

DECLARE
  v_existe NUMBER;
BEGIN
  --Si la tarjeta es de la afinidad GOURMED grabar la descripcion con el texto "CREDITO GOURMED"
  SELECT COUNT(*)
  INTO v_existe
  FROM ta_tipos
  WHERE nro_bin = substr(:new.nro_tarjeta, 1, 10)
  AND descripcion LIKE '%GOURME%';

  IF v_existe <> 0 THEN
    -- Actualizar descripcion
    :new.des_movimiento := 'CREDITO GOURMED';
  ELSE
    --Si la descripcion del movimientos contiene las palabras "REFIN" y "FINAN" entonces
    --grabar la descripcion con los textos genericos "REFINANCIACIONES" y "FINANCIACIONES".
    IF :new.des_movimiento LIKE '%REFIN%' THEN
      :new.des_movimiento := 'REFINANCIACIONES';
    ELSIF :new.des_movimiento LIKE '%FINAN%' THEN
      IF :new.des_movimiento NOT IN
         ('GASTOS FINANCIEROS', 'TRANSF SDO FINANCIAD') THEN
        --DYDMR-24804 se agrega para casos de TRANSF SDO FINANCIAD
        :new.des_movimiento := 'FINANCIACIONES';
      ELSIF :new.Des_Movimiento = 'TRANSF SDO FINANCIAD'
            AND :NEW.Tip_Movimiento = 'CR' THEN
        --DYDMR-24804 
        :new.des_movimiento := 'TR SALD FINANCIAD CR';
      ELSIF :new.Des_Movimiento = 'TRANSF SDO FINANCIAD'
            AND :NEW.Tip_Movimiento = 'DB' THEN
        --DYDMR-24804
        :new.des_movimiento := 'TR SALD FINANCIAD DB';
      END IF;
    ELSIF :new.des_movimiento LIKE 'RENOV. CUOTA%' THEN
      :new.des_movimiento := 'RENOV. CUOTA';
    ELSIF :new.des_movimiento LIKE 'CUOTA ANUAL%' THEN
      :new.des_movimiento := 'CUOTA ANUAL';
    END IF;
  END IF;
EXCEPTION
  WHEN OTHERS THEN
    IF SQLCODE < -20000 THEN
      RAISE;
    ELSE
      raise_application_error(-20000, 'TB_TA_MOV_ESPECIALES_TMP : ' ||
                               SQLERRM);
    END IF;
END;
/

