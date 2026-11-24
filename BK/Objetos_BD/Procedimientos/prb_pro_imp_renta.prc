create or replace procedure it.PRB_PRO_IMP_RENTA IS
 ingresos  NUMBER;
 egresos   NUMBER;
 impuesto  NUMBER;
 utilidad  NUMBER;
 porc_util NUMBER;
 importe   NUMBER;
 w_debcre1 varchar2(01);
 w_debcre2 varchar2(01);
 w_ctadeb  varchar2(15);
 w_ctacre  varchar2(15);
 ----
 v_cod_ofi_matriz  number(5);
 v_fec_actual      DATE;
 v_nro_asiento     NUMBER;
 v_ano             number(4);
 v_mes             number(2);
 v_hay_asiento     varchar2(1) := 'N';
 -- verifica si es fin de ejercicio
 FUNCTION lf_es_fin_ejercicio
   return varchar2 is
   v_sino varchar2(1) := 'N';
   v_mes_fiscal number(3);
   v_can_meses  number(4);
 BEGIN
     -- obtengo el nro actual de mes fiscal
     v_mes_fiscal := fug_obt_pardinamico('MES_FISCAL');
     -- obtengo la cantidad de meses del año fiscal
     v_can_meses  := fug_obt_pardinamico('CAN_MES_FISCAL');
     if v_mes_fiscal = v_can_meses then
        v_sino := 'S';
     end if;
     return v_sino;
 END;
 ---
 FUNCTION lf_obt_sal_contable(p_cod_rubro in varchar2)
    RETURN number IS
    v_saldo number;
 BEGIN
    SELECT ABS(NVL(SAL_MON_LOC_ANT,0)+NVL(DEB_MON_LOCAL,0)-NVL(CRE_MON_LOCAL,0))
      INTO v_saldo
      FROM CB_SAL_CONSOLIDADOS
     WHERE ANO = v_ano
       AND MES = v_mes
       AND COD_RUBRO = p_cod_rubro;
    return v_saldo;
 EXCEPTION
   WHEN NO_DATA_FOUND THEN
     raise_application_error(-20000,'ERROR. No existe CB_SAL_CONSOLIDADOS para cuenta '||p_cod_rubro);
   WHEN TOO_MANY_ROWS THEN
     raise_application_error(-20000,'ERROR. Registro duplicado en CB_SAL_CONSOLIDADOS para cuenta '||p_cod_rubro);
   WHEN OTHERS THEN
     raise_application_error(-20000,'ERROR Grave en CB_SAL_CONSOLIDADOS para cuenta '||p_cod_rubro||' - '||sqlerrm );
  END;
  ----
 /* Proceso mensual para la provision del impuesto a la Renta. Se corre todos los fines
    de mes, excepto si es fin de ejercicio(fin de año) */
BEGIN
  if lf_es_fin_ejercicio != 'S' then
      ---
      select cod_ofi_matriz into v_cod_ofi_matriz from ge_par_generales;
      ------- ve nro asiento -----------
      v_nro_asiento := fug_obt_pardinamico('SIG_NRO_ASIENTO');
      --------------------------
      v_fec_actual := pag_cal.fu_obt_fec_actual(2);
      /* tomo el año y mes de actual */
      v_ano := to_char(v_fec_actual,'yyyy');
      v_mes := to_char(v_fec_actual,'mm');
      -------------------------------------
      BEGIN
      SELECT COD_RUBRO INTO w_ctadeb
        FROM CB_RUBROS
       WHERE COD_RUBRO = '730107690239699'
         AND IMPUTABLE = 'S';
      EXCEPTION
        WHEN NO_DATA_FOUND THEN
           RAISE_APPLICATION_ERROR(-20000,'ERROR. No encuentra Cta. 730107690239699. Verifique');
      END;
      BEGIN
      SELECT COD_RUBRO INTO w_ctacre
        FROM CB_RUBROS
       WHERE COD_RUBRO = '240102460139999'
         AND IMPUTABLE = 'S';
      EXCEPTION
        WHEN NO_DATA_FOUND THEN
           RAISE_APPLICATION_ERROR(-20000,'ERROR. No encuentra Cta. 240102460139999. Verifique');
      END;
      ingresos := lf_obt_sal_contable('600000000000000');
      egresos  := lf_obt_sal_contable('700000000000000');
      impuesto := lf_obt_sal_contable('730107690239699');
      utilidad := ingresos - egresos + impuesto;
      -- modificado por OLGA a 10 % el 31/01/01 S/ Req.--
      porc_util := ROUND(utilidad * 0.100,0);
      importe := porc_util - impuesto;
      --------- GENERA ASIENTO --------------
      --- Debito en la linea 1 y credito en la linea 2 (valores
      --- por defecto) si el importe es positivo
      --- Si es negativo se invierte y el importe se multiplica por -1.
      ---------------------------------------
      w_debcre1 := 'D';
      w_debcre2 := 'C';
      IF importe < 0 THEN
         importe := importe * -1;
         w_debcre1 := 'C';
         w_debcre2 := 'D';
      END IF;
      ----------Va ha generar asiento de Impuesto a la Renta -------
      INSERT INTO CB_ASIENTOS
          (COD_OFICINA, NRO_ASIENTO, COD_USUARIO, FECHA,
           COD_MODULO, COD_MODALIDAD,
           TOT_CONTROL, ACTUALIZADO, REVERSADO, COD_OFI_ORIGEN,
           OFI_INTEGRADA, CONFIRMADO)
      VALUES
          (v_cod_ofi_matriz, v_nro_asiento, USER, v_fec_actual,
           2, 21 , importe*2, 'N', 'N', 0, 'N', 'S');
      ------------------------------------------
      -- carga detalles (1a. Linea)           --
      -------------------------------------------
       INSERT INTO CB_ASIENTOS_DET
         (COD_OFICINA, NRO_ASIENTO, NRO_LINEA, COD_RUBRO,
          MTO_MON_LOCAL, MTO_MON_RUBRO, TIP_MOVIMIENTO, REFERENCIA,
          DESCRIPCION, PROTEGIDO, ACTUALIZADO, VAL_COTIZACION,
          DISTRIBUIDO)
       VALUES
         (v_cod_ofi_matriz, v_nro_asiento,
         1, W_CTADEB, importe, 0, W_DEBCRE1, 'IMP.RTA',
          'ASIENTO I.RENTA' , 'N', 'N', 0 , 'N');
       ------------------------------------------
       -- carga detalles (2a. linea)           --
       ------------------------------------------
       INSERT INTO CB_ASIENTOS_DET
         (COD_OFICINA, NRO_ASIENTO, NRO_LINEA, COD_RUBRO,
          MTO_MON_LOCAL, MTO_MON_RUBRO, TIP_MOVIMIENTO, REFERENCIA,
          DESCRIPCION, PROTEGIDO,   ACTUALIZADO, VAL_COTIZACION,
          DISTRIBUIDO)
       VALUES
         (v_cod_ofi_matriz, v_nro_asiento,
          2, W_CTACRE, importe, 0,  W_DEBCRE2, 'IMP.RTA',
          'ASIENTO I.RENTA' , 'N', 'N', 0 ,'N');
       ------ fin asiento ---------
       v_hay_asiento := 'S';
       ------ ACTUALIZA PARAMETROS -----
       prg_act_par_dinamico('SIG_NRO_ASIENTO',null, null, null, null, (v_nro_asiento + 1));
       ---------------------------------
   end if;
END;
/

