create or replace procedure it.prb_asi_cos_sucursales is
  --Creado por : rpavon en Bco. Regional--
  --Finalidad  : Asientos de Costo entre Sucursales

  --Variablles--
  v_fec_actual       date := pag_cal.fu_obt_fec_actual(2);
  v_cod_mon_local    varchar2(3) := pag_gen.FU_OBT_MON_LOCAL;
  v_cod_oficina      NUMBER(03);
  v_cod_rubro        VARCHAR2(15);
  v_tot_control      NUMBER := 0;
  v_tot_con_mes_dinero NUMBER := 0;
  v_nro_linea        NUMBER;
  v_nro_lin_mes_dinero   NUMBER;
  v_nro_asiento      NUMBER;
  v_nro_asi_mes_dinero   number;
  v_diferencia       NUMBER;
  v_tip_movimiento   VARCHAR2(1);
  v_tip_mov_contra   VARCHAR2(1);
  v_lugar            varchar2(300);
  v_ano number(4) := to_number(to_char(v_fec_actual,'yyyy'));
  v_mes number(2) := to_number(to_char(v_fec_actual,'mm'));
  v_cod_ofi_mes_dinero number(3) := to_number(fug_obt_pardinamico('COD_OFI_MES_DINERO'));
  v_cod_rub_inter varchar2(15) := fug_obt_pardinamico('COD_RUB_INTEROFICINA',NULL,NULL,'GS',NULL);
  v_cod_mon_fuerte varchar2(3) := pag_gen.fu_obt_mon_fuerte;
  v_cot_mon_fuerte ge_cotizaciones.val_conversion%type := fug_obt_cotizacion(v_cod_mon_fuerte,v_fec_actual);
  v_val_cotizacion ge_cotizaciones.val_conversion%type;
  v_mto_mon_rubro cb_asientos_det.mto_mon_rubro%type;
  v_referencia cb_asientos_det.referencia%type := 'COS.SUC.';
  v_descripcion cb_asientos_det.descripcion%type := 'COSTO ENTRE SUC.Y AGE.';
  v_tot_debitos number(18,2);
  v_tot_creditos number(18,2);
  v_cod_rub_cos_mon_local  varchar2(15) := fug_obt_pardinamico('COD_RUB_COS_SUCURSALES',NULL,NULL,v_cod_mon_local,NULL);
  v_cod_rub_cos_mon_fuerte varchar2(15) := fug_obt_pardinamico('COD_RUB_COS_SUCURSALES',NULL,NULL,v_cod_mon_fuerte,NULL);

  --Definicion de Cursores--
  cursor c_oficinas is
   select cod_oficina
     from cb_cos_sucursales t
    where t.ano = v_ano
      and t.mes = v_mes
      and t.cod_oficina <> v_cod_ofi_mes_dinero
    group by cod_oficina;

  --Cursor de Costo--
  cursor c_costo is
   select cod_moneda,
          sum(nvl(mto_interes,0)) mto_interes
     from cb_cos_sucursales t
    where t.ano = v_ano
      and t.mes = v_mes
      and t.cod_oficina = v_cod_oficina
    group by cod_moneda
   having sum(nvl(mto_interes,0)) <> 0;

BEGIN
--Busco el Primer Numero de asiento disponible ------------------
v_nro_asiento := fug_obt_pardinamico('SIG_NRO_ASIENTO');

--Ciclo Principal de Oficinas--
v_tot_con_mes_dinero := 0;
v_nro_lin_mes_dinero := 0;
v_nro_asi_mes_dinero := v_nro_asiento;
for ofi in c_oficinas loop
    --Incrementa el nro. de Asiento--
    v_nro_asiento := v_nro_asiento + 1;

    --Inicializa variables por Oficina--
    v_cod_oficina := ofi.cod_oficina;
    v_nro_linea := 0;
    v_tot_control := 0;
    v_tot_creditos := 0;
    v_tot_debitos := 0;

    --Cursor de Oficinas--
    for cos in c_costo loop
       v_diferencia := 0;
       --Determina que se va a hacer: DEBITO o CREDITO--
       IF cos.mto_interes > 0 THEN
          -- SE HACE DEBITO A LA CUENTA
          v_diferencia := cos.mto_interes;
          v_tip_movimiento := 'D';
          v_tot_debitos := nvl(v_tot_debitos,0) + nvl(v_diferencia,0);
          v_tip_mov_contra := 'C';
       ELSE
          -- SE HACE CREDITO A LA CUENTA
          v_diferencia := cos.mto_interes * -1;
          v_tip_movimiento := 'C';
          v_tot_creditos := nvl(v_tot_creditos,0) + nvl(v_diferencia,0);
          v_tip_mov_contra := 'D';
       END IF;
       if cos.cod_moneda = v_cod_mon_fuerte then
          v_val_cotizacion := v_cot_mon_fuerte;
          v_mto_mon_rubro := trunc(v_diferencia / v_val_cotizacion,2);
          v_cod_rubro := v_cod_rub_cos_mon_fuerte;
       else
          v_val_cotizacion := null;
          v_mto_mon_rubro := null;
          v_cod_rubro := v_cod_rub_cos_mon_local;
       end if;

       --Acumula el total de control de cabecera--
       v_tot_control := nvl(v_tot_control,0) + (nvl(v_diferencia,0)*2);
       v_tot_con_mes_dinero := nvl(v_tot_con_mes_dinero,0) + (nvl(v_diferencia,0)*2);

       --Incrementa linea e inserta el Asiento de la Oficina--
       v_nro_linea := nvl(v_nro_linea,0) + 1;
       INSERT INTO CB_ASIENTOS_DET
            (COD_OFICINA, NRO_ASIENTO, NRO_LINEA, COD_RUBRO,
             MTO_MON_LOCAL, MTO_MON_RUBRO, TIP_MOVIMIENTO, REFERENCIA,
             DESCRIPCION, PROTEGIDO, ACTUALIZADO, VAL_COTIZACION,
             DISTRIBUIDO, FECHA)
       VALUES
            (v_cod_oficina, v_nro_asiento, v_nro_linea, v_cod_rubro,
             v_diferencia, v_mto_mon_rubro,v_tip_movimiento, v_referencia,
             v_descripcion, 'N','N', v_val_cotizacion,'N', v_fec_actual);

       --Incrementa linea e inserta el Asiento de Mesa de Dinero--
       v_nro_lin_mes_dinero := nvl(v_nro_lin_mes_dinero,0) + 1;
       INSERT INTO CB_ASIENTOS_DET
            (COD_OFICINA, NRO_ASIENTO, NRO_LINEA, COD_RUBRO,
             MTO_MON_LOCAL, MTO_MON_RUBRO, TIP_MOVIMIENTO, REFERENCIA,
             DESCRIPCION, PROTEGIDO, ACTUALIZADO, VAL_COTIZACION,
             DISTRIBUIDO, FECHA)
       VALUES
            (v_cod_ofi_mes_dinero, v_nro_asi_mes_dinero, v_nro_lin_mes_dinero, v_cod_rubro,
             v_diferencia, v_mto_mon_rubro,v_tip_mov_contra, v_referencia,
             v_descripcion, 'N','N', v_val_cotizacion,'N', v_fec_actual);
    END LOOP;

    v_diferencia := nvl(v_tot_debitos,0) - nvl(v_tot_creditos,0);
    if v_diferencia > 0 then
       v_tip_mov_contra := 'C';
       v_tip_movimiento := 'D';
    else
       v_tip_mov_contra := 'D';
       v_tip_movimiento := 'C';
       v_diferencia := v_diferencia * -1;
    end if;

    v_val_cotizacion := null;
    v_mto_mon_rubro := null;
    --Incrementa linea e inserta el Asiento de la Oficina--
    v_nro_linea := v_nro_linea + 1;
    INSERT INTO CB_ASIENTOS_DET
    (COD_OFICINA, NRO_ASIENTO, NRO_LINEA, COD_RUBRO,
     MTO_MON_LOCAL, MTO_MON_RUBRO, TIP_MOVIMIENTO, REFERENCIA,
     DESCRIPCION, PROTEGIDO, ACTUALIZADO, VAL_COTIZACION,
     DISTRIBUIDO, FECHA)
    VALUES
    (v_cod_oficina, v_nro_asiento, v_nro_linea, v_cod_rub_inter,
     v_diferencia, v_mto_mon_rubro,v_tip_mov_contra, v_referencia,
     'INTEROFICINA', 'N','N', v_val_cotizacion,'N', v_fec_actual);

    --Incrementa linea e inserta el Asiento de Mesa de Dinero--
    v_nro_lin_mes_dinero := nvl(v_nro_lin_mes_dinero,0) + 1;
    INSERT INTO CB_ASIENTOS_DET
    (COD_OFICINA, NRO_ASIENTO, NRO_LINEA, COD_RUBRO,
     MTO_MON_LOCAL, MTO_MON_RUBRO, TIP_MOVIMIENTO, REFERENCIA,
     DESCRIPCION, PROTEGIDO, ACTUALIZADO, VAL_COTIZACION,
     DISTRIBUIDO, FECHA)
    VALUES
    (v_cod_ofi_mes_dinero, v_nro_asi_mes_dinero, v_nro_lin_mes_dinero, v_cod_rub_inter,
     v_diferencia, v_mto_mon_rubro,v_tip_movimiento, v_referencia,
     'INTEROFICINA', 'N','N', v_val_cotizacion,'N', v_fec_actual);

    --Actualiza/Inserta el Asiento de la Oficina--
    INSERT INTO CB_ASIENTOS
    (COD_OFICINA, NRO_ASIENTO, COD_USUARIO, FECHA,
     COD_MODULO, COD_MODALIDAD,
     TOT_CONTROL, ACTUALIZADO, REVERSADO, COD_OFI_ORIGEN,
     OFI_INTEGRADA, CONFIRMADO)
    VALUES
    (v_cod_oficina, v_nro_asiento,user,
     v_fec_actual, 2, 21,
     v_tot_control, 'N','N', NULL,'N', 'S');
end loop;
--Inserta/Actualiza el asiento de Mesa de Dinero--
INSERT INTO CB_ASIENTOS
(COD_OFICINA, NRO_ASIENTO, COD_USUARIO, FECHA,
 COD_MODULO, COD_MODALIDAD,
 TOT_CONTROL, ACTUALIZADO, REVERSADO, COD_OFI_ORIGEN,
 OFI_INTEGRADA, CONFIRMADO)
VALUES
(v_cod_ofi_mes_dinero, v_nro_asi_mes_dinero,user,
 v_fec_actual, 2, 21,
 v_tot_con_mes_dinero, 'N','N', NULL,'N', 'S');

--ACTUALIZA PARAMETROS--
prg_act_par_dinamico('SIG_NRO_ASIENTO',null, null, null, null, v_nro_asiento+1);

EXCEPTION
   WHEN OTHERS THEN
     raise_application_error(-20000,'ERROR. en prb_asi_cos_sucursales. '||v_lugar||'-'||SQLERRM);
END prb_asi_cos_sucursales;
/

