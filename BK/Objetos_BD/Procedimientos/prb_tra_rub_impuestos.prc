create or replace procedure it.prb_tra_rub_impuestos is
  --Creado por : rpavon en Bco. Regional--
  --Finalidad  : Transferir contablemente los saldos de las ctas de impuestos
  --             a la oficina 1--

  --Variablles--
  v_fec_actual       date := pag_cal.fu_obt_fec_actual(2);
  v_cod_mon_local    varchar2(3) := pag_gen.FU_OBT_MON_LOCAL;
  v_cod_oficina      NUMBER(03);
  v_cod_rubro        VARCHAR2(15);
  v_aju_oficina      VARCHAR2(01);
  v_sal_mon_local    NUMBER(16,2);
  v_sal_mon_rubro    NUMBER(16,2);
  v_mto_mon_local    number(18,2);
  v_mto_mon_rubro    number(18,2);
  v_cod_tip_cuenta   NUMBER(2);
  v_cod_moneda       VARCHAR2(3);
  v_tot_control      NUMBER := 0;
  v_tot_con_cabecera NUMBER := 0;
  v_nro_linea        NUMBER;
  v_nro_lin_matriz   NUMBER;
  v_nro_asiento      NUMBER;
  v_nro_asi_matriz   number;
  v_diferencia       NUMBER;
  v_tip_movimiento   VARCHAR2(1);
  v_tip_mov_contra   VARCHAR2(1);
  v_cod_ofi_matriz   number(3) := TO_NUMBER(fug_obt_pardinamico('COD_OFI_CAS_MATRIZ',NULL,NULL,NULL,NULL));
  v_cod_gru_tra_saldos number(5) := TO_NUMBER(fug_obt_pardinamico('COD_GRU_RUB_TRA_SALDOS',NULL,NULL,NULL,NULL));
  v_cod_rub_inter    varchar2(15);
  v_lugar            varchar2(300);
  v_contador         number(5) := 0;
  v_val_cotizacion   ge_cotizaciones.val_conversion%type;

  --Definicion de Cursores--
  CURSOR c_oficinas IS
     SELECT COD_OFICINA,DESCRIPCION
       FROM BA_OFICINAS x
      where x.cod_oficina <> v_cod_ofi_matriz
        and exists (
      SELECT 1
        FROM CB_SAL_OFICINAS b, CB_RUBROS a, cb_gru_rubros_det c
       WHERE a.imputable = 'S'
         and c.cod_gru_rubro = v_cod_gru_tra_saldos
         and c.cod_rubro = a.cod_rubro
         and b.cod_rubro = a.cod_rubro
         --Controlar si tiene saldo--
         and ((NVL(SAL_MON_LOC_ANT,0)+NVL(DEB_MON_LOCAL,0)-NVL(CRE_MON_LOCAL,0) <> 0) or
              (NVL(SAL_MON_RUB_ANT,0)+NVL(DEB_MON_RUBRO,0)-NVL(CRE_MON_RUBRO,0) <> 0))
         and b.cod_oficina = x.cod_oficina
                     )
      ORDER BY COD_OFICINA;

  CURSOR c_rubros is
      SELECT a.COD_RUBRO, AJUSTABLE,
             NVL(SAL_MON_LOC_ANT,0)+NVL(DEB_MON_LOCAL,0)-NVL(CRE_MON_LOCAL,0),
             NVL(SAL_MON_RUB_ANT,0)+NVL(DEB_MON_RUBRO,0)-NVL(CRE_MON_RUBRO,0),
             TIPO, a.COD_MONEDA
        FROM CB_SAL_OFICINAS b, CB_RUBROS a, cb_gru_rubros_det c
       WHERE a.imputable = 'S'
         and c.cod_gru_rubro = v_cod_gru_tra_saldos
         and c.cod_rubro = a.cod_rubro
         and b.cod_rubro = a.cod_rubro
         and b.cod_oficina = v_cod_oficina
         --Controlar si tiene saldo--
         and ((NVL(SAL_MON_LOC_ANT,0)+NVL(DEB_MON_LOCAL,0)-NVL(CRE_MON_LOCAL,0) <> 0) or
              (NVL(SAL_MON_RUB_ANT,0)+NVL(DEB_MON_RUBRO,0)-NVL(CRE_MON_RUBRO,0) <> 0))
      ORDER BY a.COD_MONEDA,a.COD_RUBRO,b.COD_OFICINA;
v_redondeo number(2) := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',2,21,pag_gen.fu_obt_mon_local);
BEGIN
--- Busco el Primer Numero de asiento disponible ------------------
v_nro_asiento := fug_obt_pardinamico('SIG_NRO_ASIENTO');
v_nro_asiento := v_nro_asiento - 1;

--- Busco la Cuenta Interoficina--
v_cod_rub_inter := fug_obt_pardinamico('COD_RUB_INTEROFICINA',NULL,NULL,'GS',NULL);

--- Ciclo de lectura de las cuentas ordenado por Moneda,Cuenta,Of.--
v_contador := 0;
for ofi in c_oficinas loop
    --Incrementa el contador--
    v_contador := v_contador + 1;

    if v_contador = 1 then
       --Inicializa Variables--
       v_tot_con_cabecera := 0;
       v_nro_lin_matriz := 0;

       --Incrementa Nros. de Asientos--
       v_nro_asiento := v_nro_asiento + 1;
       v_nro_asi_matriz := v_nro_asiento;

       --Inserta el Asiento de la Casa Matriz--
       INSERT INTO CB_ASIENTOS
       (COD_OFICINA, NRO_ASIENTO, COD_USUARIO, FECHA,
        COD_MODULO, COD_MODALIDAD,
        TOT_CONTROL, ACTUALIZADO, REVERSADO, COD_OFI_ORIGEN,
        OFI_INTEGRADA, CONFIRMADO)
       VALUES
       (v_cod_ofi_matriz, v_nro_asi_matriz,user,
        v_fec_actual, 2, 21,
        v_tot_control, 'N','N', NULL,'N', 'S');
    end if;

    --Inicializa variables por Oficina--
    v_cod_oficina := ofi.cod_oficina;
    v_nro_linea := 0;
    v_tot_control := 0;

    --Incrementa Nros. de Asientos--
    v_nro_asiento := v_nro_asiento + 1;

    --Inserta el Asiento de la Oficina--
    INSERT INTO CB_ASIENTOS
    (COD_OFICINA, NRO_ASIENTO, COD_USUARIO, FECHA,
     COD_MODULO, COD_MODALIDAD,
     TOT_CONTROL, ACTUALIZADO, REVERSADO, COD_OFI_ORIGEN,
     OFI_INTEGRADA, CONFIRMADO)
    VALUES
    (v_cod_oficina, v_nro_asiento,user,
     v_fec_actual, 2, 21,
     v_tot_control, 'N','N', NULL,'N', 'S');

    --Recorre el cursor de rubros de la oficina--
    OPEN c_rubros;
    LOOP
    v_lugar := 'Antes del Fetch ';
    FETCH c_rubros INTO v_cod_rubro, v_aju_oficina,
                        v_sal_mon_local, v_sal_mon_rubro, v_cod_tip_cuenta,
                        v_cod_moneda;
    v_lugar := 'Despues del fectch c_rubros';
    EXIT WHEN c_rubros%notfound;
    v_diferencia := 0;

    IF ((v_sal_mon_local <> 0) or (v_sal_mon_rubro <> 0)) THEN
       --Determina que se va a hacer: DEBITO o CREDITO--
       IF ((v_sal_mon_local > 0) or (v_sal_mon_rubro > 0)) THEN
          -- SE HACE DEBITO A LA CUENTA
          v_tip_movimiento := 'C';
          v_tip_mov_contra := 'D';
          if v_cod_moneda = v_cod_mon_local then
             v_diferencia   := v_sal_mon_local;
             v_mto_mon_local := v_diferencia;
             v_sal_mon_rubro := null;
             v_val_cotizacion := null;
          else
             v_val_cotizacion := fug_obt_cotizacion(v_cod_moneda,v_fec_actual);
             v_diferencia    := v_sal_mon_rubro;
             v_mto_mon_local := round(v_diferencia * v_val_cotizacion,v_redondeo);
             v_sal_mon_rubro := v_diferencia;
          end if;
       ELSE
          -- SE HACE CREDITO A LA CUENTA
          v_tip_movimiento := 'D';
          v_tip_mov_contra := 'C';
          if v_cod_moneda = v_cod_mon_local then
             v_diferencia   := v_sal_mon_local * -1;
             v_mto_mon_local := v_diferencia;
             v_sal_mon_rubro := null;
             v_val_cotizacion := null;
          else
             v_val_cotizacion := fug_obt_cotizacion(v_cod_moneda,v_fec_actual);
             v_diferencia    := v_sal_mon_rubro * -1;
             v_mto_mon_local := round(v_diferencia * v_val_cotizacion,v_redondeo);
             v_sal_mon_rubro := v_diferencia;
          end if;
       END IF;

       --Acumula el total de control de cabecera--
       v_tot_control := nvl(v_tot_control,0) + (nvl(v_mto_mon_local,0)*2);
       v_tot_con_cabecera := nvl(v_tot_con_cabecera,0) + (nvl(v_mto_mon_local,0)*2);

       --Incrementa linea e inserta el Asiento de la Oficina--
       v_nro_linea := nvl(v_nro_linea,0) + 1;
       INSERT INTO CB_ASIENTOS_DET
            (COD_OFICINA, NRO_ASIENTO, NRO_LINEA, COD_RUBRO,
             MTO_MON_LOCAL, MTO_MON_RUBRO, TIP_MOVIMIENTO, REFERENCIA,
             DESCRIPCION, PROTEGIDO, ACTUALIZADO, VAL_COTIZACION,
             DISTRIBUIDO, FECHA)
       VALUES
            (v_cod_oficina, v_nro_asiento, v_nro_linea, v_cod_rubro,
             v_mto_mon_local, v_mto_mon_rubro,v_tip_movimiento, 'TRANSF.',
             'TRANSF.IMPUESTOS', 'N','N', v_val_cotizacion,'N', v_fec_actual);

       v_nro_linea := v_nro_linea + 1;
       INSERT INTO CB_ASIENTOS_DET
            (COD_OFICINA, NRO_ASIENTO, NRO_LINEA, COD_RUBRO,
             MTO_MON_LOCAL, MTO_MON_RUBRO, TIP_MOVIMIENTO, REFERENCIA,
             DESCRIPCION, PROTEGIDO, ACTUALIZADO, VAL_COTIZACION,
             DISTRIBUIDO, FECHA)
       VALUES
            (v_cod_oficina, v_nro_asiento, v_nro_linea, v_cod_rub_inter,
             v_mto_mon_local, v_mto_mon_rubro,v_tip_mov_contra, 'TRANSF.',
             'TRANSF.IMPUESTOS', 'N','N', v_val_cotizacion,'N', v_fec_actual);

       --Incrementa linea e inserta el Asiento de Casa Matriz--
       v_nro_lin_matriz := nvl(v_nro_lin_matriz,0) + 1;
       INSERT INTO CB_ASIENTOS_DET
            (COD_OFICINA, NRO_ASIENTO, NRO_LINEA, COD_RUBRO,
             MTO_MON_LOCAL, MTO_MON_RUBRO, TIP_MOVIMIENTO, REFERENCIA,
             DESCRIPCION, PROTEGIDO, ACTUALIZADO, VAL_COTIZACION,
             DISTRIBUIDO, FECHA)
       VALUES
            (v_cod_ofi_matriz, v_nro_asi_matriz, v_nro_lin_matriz, v_cod_rub_inter,
             v_mto_mon_local, v_mto_mon_rubro,v_tip_movimiento, 'TRANSF.',
             'TRANSF.IMPUESTOS', 'N','N', v_val_cotizacion,'N', v_fec_actual);

       v_nro_lin_matriz := nvl(v_nro_lin_matriz,0) + 1;
       INSERT INTO CB_ASIENTOS_DET
            (COD_OFICINA, NRO_ASIENTO, NRO_LINEA, COD_RUBRO,
             MTO_MON_LOCAL, MTO_MON_RUBRO, TIP_MOVIMIENTO, REFERENCIA,
             DESCRIPCION, PROTEGIDO, ACTUALIZADO, VAL_COTIZACION,
             DISTRIBUIDO, FECHA)
       VALUES
            (v_cod_ofi_matriz, v_nro_asi_matriz, v_nro_lin_matriz, v_cod_rubro,
             v_mto_mon_local, v_mto_mon_rubro,v_tip_mov_contra, 'TRANSF.',
             'TRANSF.IMPUESTOS', 'N','N', v_val_cotizacion,'N', v_fec_actual);
    end if;
    END LOOP;
    CLOSE c_rubros;

    --Actualiza el total de control de los asientos--
    update cb_asientos a
       set a.tot_control = v_tot_control
     where a.fecha = v_fec_actual
       and a.cod_oficina = v_cod_oficina
       and a.nro_asiento = v_nro_asiento;

end loop;
--Actualiza el asiento de Casa Matriz--
update cb_asientos a
   set a.tot_control = v_tot_con_cabecera
 where a.fecha = v_fec_actual
   and a.cod_oficina = v_cod_ofi_matriz
   and a.nro_asiento = v_nro_asi_matriz;

--ACTUALIZA PARAMETROS--
v_nro_asiento := v_nro_asiento + 1;
prg_act_par_dinamico('SIG_NRO_ASIENTO',null, null, null, null, v_nro_asiento);

EXCEPTION
   WHEN VALUE_ERROR THEN
     CLOSE c_rubros;
     raise_application_error(-20000,' ERROR. En valores del Procedure PROCESO_DE_AJUSTE '||'-'||v_lugar);
   WHEN OTHERS THEN
     CLOSE c_rubros;
     raise_application_error(-20000,'ERROR. en. '||v_lugar||'-'||SQLERRM);
END prb_tra_rub_impuestos;
/

