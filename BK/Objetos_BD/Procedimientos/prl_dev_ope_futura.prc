create or replace procedure it.PRL_DEV_OPE_FUTURA is
  r_lofut           lc_ope_futuras%rowtype;
  v_cod_moneda      ba_monedas.cod_moneda%type;
  v_cod_mon_local   ba_monedas.cod_moneda%type := pag_gen.fu_obt_mon_local ;
  v_fila            varchar2(18);
  v_fec_actual      ge_calendarios.fec_actual%type;
  v_ano_mes_actual      varchar2(6);
  v_ano_mes_liquidacion varchar2(6);
  v_ano_mes_operacion   varchar2(6);
  v_ano_mes_vencimiento varchar2(6);
  v_mto_emi_gs      number(18,2);
  v_mto_ven_gs      number(18,2);
  v_dia_inicio      number(18);
  v_mto_diferencia  number(18);
  v_int_devengado   number(18,2);
  v_dia_fin         number(18);
  v_mto_dia         number(18,2);
  v_cantidad        number(18);
  v_descuento       varchar2(1);
  v_fec_pri_mes     date;
  v_fec_ult_mes     date;
  v_ind_dev_val_economico ge_par_dinamicos.val_parametro%type;
  --
  cursor fut is
       select f.cotizacion, f.cot_vencimiento, f.monto, f.plazo,
              f.fec_liquidacion, f.fec_operacion, f.fec_vencimiento, f.cod_moneda,
              f.rowid, f.cod_mad_padre, f.cod_ofi_origen
         from lc_ope_futuras f
        where f.cod_mad_padre = 76
          and f.estado in ('N','L') -- CB. 28/08/2013
          and ( f.fec_liquidacion is null or
              ( f.fec_liquidacion between v_fec_pri_mes and v_fec_ult_mes) )
          and ((v_ind_dev_val_economico = 'N') or 
               (v_ind_dev_val_economico = 'S' and 
                exists (select 1 
                          from ba_cod_referencias x
                         where x.dominio = 'OPE_FUT_DEV_ANTERIOR'
                           and x.val_minimo = f.nro_cuenta||'#'||f.nro_operacion)));
   --
begin
  begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 7; end;
  Begin PAG_CAL.PR_OBT_DAT_CALENDAR(7);End;
  --
  v_fec_pri_mes := pag_cal.g_pri_dia_mes;
  v_fec_ult_mes := pag_cal.g_ult_dia_mes;
  v_Fec_actual  := pag_cal.g_fec_actual;
  v_ano_mes_Actual := TO_CHAR(v_Fec_actual,'YYYYMM');
  v_cantidad    := 0;
  v_ind_dev_val_economico := nvl(fug_obt_pardinamico('IND_DEV_VAL_ECONOMICO'),'N');
  OPEN fut;
  LOOP
    FETCH fut INTO r_lofut.cotizacion, r_lofut.cot_vencimiento, r_lofut.monto, r_lofut.plazo,
                   r_lofut.fec_liquidacion, r_lofut.fec_operacion, r_lofut.fec_vencimiento, r_lofut.cod_moneda,
                   v_fila, r_lofut.cod_mad_transaccion, r_lofut.cod_ofi_origen;
    EXIT WHEN fut%NOTFOUND;
    v_cantidad := v_cantidad + 1;
    ----------------------------------------------------------
    v_mto_emi_gs := r_lofut.cotizacion * r_lofut.monto;
    v_mto_ven_gs := r_lofut.cot_vencimiento * r_lofut.monto;
    v_mto_diferencia := abs(v_mto_ven_gs-v_mto_emi_gs);
    v_mto_dia := v_mto_diferencia/r_lofut.plazo;
    v_int_devengado := 0;
    v_ano_mes_liquidacion := TO_CHAR(r_lofut.fec_liquidacion, 'YYYYMM');
    v_ano_mes_operacion := TO_CHAR(r_lofut.fec_operacion, 'YYYYMM');
    v_ano_mes_vencimiento := TO_CHAR(r_lofut.fec_vencimiento, 'YYYYMM');
    -- Verifico si es un premio o un descuento ---------------
    IF NVL(r_lofut.cot_vencimiento,0) >= NVL(r_lofut.cotizacion,0) THEN
       v_descuento := 'N';
    ELSE
       v_descuento := 'S';
    END IF;
    ----------------------------------------------------------
    -- 1. Mes de concresion igual al mes actual y
    --    mes de emision menor al mes actual
    -----------------------------------------------------
    IF v_ano_mes_vencimiento = v_ano_mes_actual AND
       v_ano_mes_operacion < v_ano_mes_actual THEN
       v_dia_fin := TO_CHAR(r_lofut.fec_vencimiento,'DD');
       v_dia_inicio := 1;
    END IF;
    -- 2. Mes de concresion igual al mes actual y
    --    mes de emision igual al mes actual.
    ---------------------------------------------------------
    IF nvl(v_ano_mes_liquidacion,' ') = v_ano_mes_actual AND
       v_ano_mes_operacion = v_ano_mes_actual THEN
       v_dia_fin := TO_CHAR(r_lofut.fec_vencimiento,'DD');
       v_dia_inicio := TO_CHAR(r_lofut.fec_operacion,'DD');
    END IF;
    -- 3. Mes de concresion es nulo, Mes de emision igual al
    --    mes actual y mes de liquidacion mayor al mes actual.
    ----------------------------------------------------------
    IF v_ano_mes_operacion = v_ano_mes_actual AND
       v_ano_mes_liquidacion IS NULL       AND
       v_ano_mes_vencimiento > v_ano_mes_actual THEN
       v_dia_fin := TO_CHAR(v_fec_ult_mes,'DD');
       v_dia_fin := v_dia_fin + 1;
       v_dia_inicio := TO_CHAR(r_lofut.fec_operacion,'DD');
    END IF;
    -- 5. Mes de emision es menor a mes actual y
    --    mes de concresion igual a nulo y
    --    mes de liquidacion es mayor al mes actual.
    ---------------------------------------------------------
    IF v_ano_mes_operacion < v_ano_mes_actual AND
       v_ano_mes_liquidacion IS NULL       AND
       v_ano_mes_vencimiento > v_ano_mes_actual THEN
       v_dia_fin := TO_CHAR(v_fec_ult_mes,'DD');
       v_dia_fin := v_dia_fin + 1;
       v_dia_inicio := 1;
    END IF;
    -- Calcula el importe diario de devengamiento multiplicado
    -- por la cantidad de dias transcurridos.
    ---------------------------------------------------------
    v_int_devengado := round((v_dia_fin-v_dia_inicio) * v_mto_dia,0);
    if (v_int_devengado is not null and nvl(v_int_devengado,0) <> 0) then --NVB-1280
        INSERT INTO lc_devengados
          (nro_cuenta, fecha, cod_modulo, cod_modalidad, cod_moneda, cod_oficina, nro_operacion, estado,
           can_dia_interes, mto_interes, mto_dev_acumulado,
           cod_mad_transaccion, cod_mad_padre, cod_ofi_origen, descuento,val_tasa)
        SELECT
          nro_cuenta, v_Fec_actual, cod_modulo, cod_modalidad, v_cod_mon_local, cod_oficina, nro_operacion, 'M',
          (v_dia_fin-v_dia_inicio), v_int_devengado, v_int_devengado,
          cod_mad_transaccion, cod_mad_padre, cod_ofi_origen, v_descuento,0
          FROM LC_OPE_FUTURAS
         WHERE Rowid = v_fila;
    end if;
    ------------------------------------------------------
  END LOOP;

end PRL_DEV_OPE_FUTURA;
/

