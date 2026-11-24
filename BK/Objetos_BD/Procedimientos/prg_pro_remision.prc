CREATE OR REPLACE PROCEDURE IT.prg_pro_remision
(p_cod_servicio in ge_cob_ser_parametros.cod_servicio%type,
 p_cod_oficina  in ge_cob_ser_parametros.cod_oficina%type,
 p_fec_hasta    in date  default null)IS
/*proceso de remision de cobros de servicios realizados
Recibe el codigo del servicio a procesar, si se recibe 999 se procesan todos
los servicios que esten pendientes de remitir.
Recibe la oficina si es que se puede procesar por oficina. Si en ge_cob_ser_parametros
esta indicado CENTRALIZADO = S significa que se deben procesar todas las oficinas no se puede
procesar una oficina particular, sino se puede recibir la oficina del usuario para procesar solo esa.
Se procesan todos los cobros que se hayan realizado (P), los que dieron error (E) tambien
entran en el proceso pero solo para ser marcados como remitidos, ya que no se calcula nada sobre ellos.
*/
  v_cod_servicio number;
  CURSOR detalle IS
     SELECT distinct b.COD_SERVICIO, CENTRALIZADO,
            DECODE(b.TIP_COBRO,'A','A','X') TIP_COBRO,
            DECODE(b.tip_cobro,'A',b.fecha,to_date(null,'dd/mm/yyyy')) fec_proceso,
            a.descripcion
       FROM GE_COB_SERVICIOS b, ge_cob_ser_parametros a
      where B.FEC_REMISION is null
        and B.NRO_REMISION is null
        and B.estado = 'P' --procesado (cobrado)
        and (b.fecha <= p_fec_hasta or p_fec_hasta is null)
        and b.cod_servicio = a.cod_servicio
        and (b.COD_SERVICIO = p_cod_servicio or p_cod_servicio = 999)
        and (COD_OFI_origen = p_cod_oficina or p_cod_oficina = 999);
  --------------------------------------------
  CURSOR datoser IS
     SELECT *
       FROM GE_COB_SER_PARAMETROS
      where COD_SERVICIO = v_cod_servicio;
  -------------------------------------------
  CURSOR importe(p_tip_cobro varchar2, p_fec_proceso date) IS
     SELECT nvl(MONTO,0), B.rowid, COD_MONEDA,
            TIP_COBRO, FECHA, HORA, nvl(mto_che_nue_banco,0), nvl(MTO_CHE_OTR_BANCO,0),
            nvl(mto_efectivo,0), nvl(mto_debito,0),
            mto_comision, mto_impuesto
       FROM GE_COB_SERVICIOS B, GE_COB_SER_PARAMETROS A
      where b.FEC_REMISION is null
        and b.NRO_REMISION is null
        and b.COD_SERVICIO = v_cod_servicio
        and ((b.tip_cobro = p_tip_cobro) or (p_tip_cobro = 'X'  and b.tip_cobro <> 'A'))
        and b.estado = 'P' --procesado (cobrado)
        and (b.fecha <= p_fec_hasta or p_fec_hasta is null)
        and ((b.fecha = p_fec_proceso) or (p_fec_proceso is null and b.tip_cobro <> 'A'))
        and b.cod_servicio = a.cod_servicio
        and ((COD_OFI_origen = p_cod_oficina and centralizado = 'N')
             or (p_cod_oficina = 999 and centralizado ='S'));
  --------VARIABLES GENERALES-----------------
  v_error            EXCEPTION;
  v_mensaje          varchar2(8000);
  v_por_tasa         number;
  v_cod_tas_cargo    ge_tasas.cod_tasa%type;
  v_val_cargo        number;
  v_cod_tra_impuesto ge_transacciones.cod_transaccion%type;
  v_cod_tas_impuesto ge_tasas.cod_tasa%type;
  v_val_impuesto     number;
  v_val_tas_cargo    number;
  v_val_tas_impuesto number;
  v_tip_cob_cabecera varchar2(1);
  v_comision         number(18,2);
  v_iva              number(18,2);
  v_cob_neto         number(18,2);
  v_tot_comision     number(18,2);
  v_tot_iva          number(18,2);
  v_tot_neto         number(18,2);
  v_nro_remito       number(7);
  v_tip_val_cargo    varchar2(1);
  v_tip_val_iva      varchar2(1);
  v_fec_proceso      date;
  v_referencia       varchar2(40);
  v_fecha            date := pag_cal.FU_OBT_FEC_ACTUAL(1);
  v_hora             ge_movimientos.hora%type := fug_ini_hora(SYSDATE,'HH24:MI:SS');
  v_nro_secuencia    ge_movimientos.nro_secuencia%type;
  v_ofi_origen       ba_oficinas.cod_oficina%type;
  v_cantidad         number := 0;
  v_mon_cta_servicio ba_monedas.cod_moneda%type;
  v_mto_cobrado      number(18,2);
  v_registro         varchar2(30);
  v_tip_cobro        varchar2(06);
  v_fec_cobro        date;
  v_hor_cobro        varchar2(08);
  --w1_cheqobc       number(18,2);
  v_cod_moneda       varchar2(3);
  v_mto_efectivo     ge_cob_servicios.mto_efectivo%type;
  v_mto_debito       ge_cob_servicios.mto_debito%type;
  v_mto_che_nuestro  ge_cob_servicios.mto_che_nue_banco%type;
  v_mto_che_otros    ge_cob_servicios.mto_che_otr_banco%type;
  v_tot_efectivo     ge_cob_servicios.mto_efectivo%type;
  v_tot_debito       ge_cob_servicios.mto_debito%type;
  v_tot_che_nuestro  ge_cob_servicios.mto_che_nue_banco%type;
  v_tot_che_otros    ge_cob_servicios.mto_che_otr_banco%type;
  v_mod_cta          ge_cuentas.cod_modulo%type;
  v_mad_cta          ge_cuentas.cod_modalidad%type;
  v_est_cta          ge_cuentas.estado%type;
  v_sal_disponible   ah_cta_vistas.sal_total%type;
  v_procesa          varchar2(1);
  servi              datoser%rowtype;
  v_centralizado     ge_cob_ser_parametros.centralizado%type;
  v_mon_local        ba_monedas.cod_moneda%type := pag_gen.FU_OBT_MON_LOCAL;
  v_redondeo         number(5);
  v_des_servicio     ge_cob_ser_parametros.descripcion%type;
--funcion local que retorna el tipo de valor de la tasa
function lf_obt_tip_valor(p_cod_tasa in ge_tasas.cod_tasa%type)
return varchar2 is
v_tip_valor ge_tasas.tip_valor%type;
begin
 if p_cod_tasa is not null then
   SELECT tip_valor
   INTO   v_tip_valor
   FROM   ge_tasas
   WHERE  cod_tasa = p_cod_tasa;
 end if;
 return v_tip_valor;
exception
  when no_data_found then
     raise_application_error(-20100, 'Tasa no definida '||p_cod_tasa);
  when others then
     raise_application_error(-20100, 'Obt.tipo valor tasa '||p_cod_tasa||'.'||sqlerrm);
end;
BEGIN
begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
   --obtener la oficina del usuario
   --solo si se recibe 999 para procesar todas las oficinas
   BEGIN
      select cod_oficina
        into v_ofi_origen
        from ba_usuarios
       where cod_usuario = USER;
   EXCEPTION
      when others then
        raise_application_error(-20130,'Al recup.oficina del usuario '||sqlerrm);
   END;
   ----
   --los cobros de servicios pendientes de remitir
   IF detalle%ISOPEN THEN
      CLOSE detalle;
   END IF;
   OPEN detalle;
   LOOP
      FETCH detalle
      INTO  v_cod_servicio, v_centralizado, v_tip_cob_cabecera, v_fec_proceso,v_des_servicio;
      EXIT WHEN detalle%NOTFOUND;
      ---------------------------
      --determina si puede procesar por oficina si no es centralizado
      --si es centralizado debe procesar todas las oficinas
      if v_centralizado = 'S' then
         if nvl(p_cod_oficina, 999) <> 999 then --si envio todas las oficinas procesar, sino no
            v_mensaje := 'El proceso es centralizado, no puede procesar una sola oficina';
            exit;
            --raise_application_error(-20200,'El proceso es centralizado, no puede procesar una sola oficina');
         end if;
      else --no es centralizado, puede procesar su oficina
         if nvl(p_cod_oficina, 999) = 999 then
            v_mensaje := 'El proceso no es centralizado, no puede procesar todas las oficinas';
            exit;
            --raise_application_error(-20200,'El proceso no es centralizado, no puede procesar todas las oficinas');
         elsif nvl(p_cod_oficina,999) <> v_ofi_origen then
            exit;
            v_mensaje := 'El proceso no es centralizado, solo puede procesar la oficina actual';
            --raise_application_error(-20200,'El proceso no es centralizado, solo puede procesar la oficina actual');
         end if;
      end if;
      v_tot_comision    := 0;
      v_tot_iva         := 0;
      v_tot_neto        := 0;
      v_tot_che_nuestro := 0;
      v_tot_che_otros   := 0;
      v_tot_efectivo    := 0;
      v_tot_debito      := 0;
      v_cantidad        := 0;
      --datos de cada servicio
      IF datoser%ISOPEN THEN
       CLOSE datoser;
      END IF;
      OPEN datoser;
      LOOP
         FETCH datoser
         INTO  servi;
         EXIT WHEN datoser%NOTFOUND;
         ------------------------------------
         ----CICLO PRINCIPAL DEL PROGRAMA----
         --obtener datos de la cuenta de credito
         pag_cta.pr_obt_cuenta(servi.nro_cuenta);
         v_mon_cta_servicio := pag_cta.G_CTAS.cod_moneda;

         --obtener TASA DE LA COMISION y el impuesto(IVA)- se le envia cualquier monto,xq solo se necesitan las tasas
         prg_obt_cargos(pag_cta.g_ctas.cod_oficina, servi.nro_cuenta, v_mon_cta_servicio, 999999,
                       servi.cod_modulo, servi.cod_modalidad, servi.cod_tra_comision,
                       v_cod_tas_cargo, v_val_tas_cargo, v_val_cargo, v_cod_tra_impuesto, v_cod_tas_impuesto,
                       v_val_tas_impuesto, v_val_impuesto);
         --recuperar el tipo valor de la tasa del cargo
         v_tip_val_cargo := lf_obt_tip_valor(v_cod_tas_cargo);
         --recuperar el tipo valor de la tasa del impuesto
         v_tip_val_iva := lf_obt_tip_valor(v_cod_tas_impuesto);
         ----ACTUALIZAR montos de comision e iva en los detalles-------
         v_redondeo   := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',servi.cod_modulo, servi.cod_modalidad,v_mon_cta_servicio);
         --detalles de los cobros realizados
         IF importe%ISOPEN THEN
           CLOSE importe;
         END IF;
         OPEN importe(v_tip_cob_cabecera, v_fec_proceso);
         LOOP
            FETCH importe
            INTO v_mto_cobrado, v_registro, v_cod_moneda, v_tip_cobro, v_fec_cobro, v_hor_cobro,
                  v_mto_che_nuestro, v_mto_che_otros, v_mto_efectivo, v_mto_debito, v_comision,
                  v_iva;
            EXIT WHEN importe%NOTFOUND;
            if NVL(servi.tip_monto,'X') = 'N' and v_comision > 0 and v_tip_cobro = 'A' then
               -- el tipo de monto es net
               v_cob_neto := nvl(v_mto_cobrado,0) - (nvl(v_comision,0) + nvl(v_iva,0));
            else
              -- solo ya se calcula si es bruto, sino se toma lo que viene calculado
              ---DETERMINACION DEL TIPO DE COMISION---
              IF servi.COM_INCLUIDA = 'S' then
                 /*COMISION INCLUIDA EN MONTO COBRADO*/
                 IF v_tip_val_cargo = 'P' THEN
                    v_por_tasa  := (v_val_tas_cargo*100) / (100 + v_val_tas_impuesto);
                    v_comision := ROUND((v_mto_cobrado * v_por_tasa) / (100 + v_val_tas_cargo),v_redondeo);
                 ELSE
                    v_comision := nvl(v_val_tas_cargo,0);
                 END IF;
                 v_iva := nvl(ROUND((v_comision * v_val_tas_impuesto) / (100),v_redondeo),0);
                 v_cob_neto := nvl(v_mto_cobrado,0) - (nvl(v_comision,0) + nvl(v_iva,0));
              ELSE /*comision no incluida en el monto cobrado*/
                 -----DETERMINA SI ES TARIFA O PORCENTAJE-----
                 IF v_tip_val_cargo = 'P' THEN
                    v_comision := ROUND((nvl(v_mto_cobrado,0) * nvl(v_val_tas_cargo,0)) / 100,v_redondeo);
                 ELSE /*ES TARIFA 'V'*/
                    v_comision := nvl(v_val_tas_cargo,0);
                 END IF;
                 ----------------------------------------------
                 --el impuesto siempre esta incluido en la comision --OJO VER!!!
                 --IF servi.TIP_IMPUESTO = 'I' then
                 ------IVA INCLUIDA EN COMISION------
                 v_iva := nvl(ROUND((v_comision * v_val_tas_impuesto) / (100 + v_val_tas_impuesto),v_redondeo),0);
                 v_comision := nvl(v_comision,0) - nvl(v_iva,0);
                 v_cob_neto := nvl(v_mto_cobrado,0);
                 /*ELSE
                    -----IVA NO INCLUIDO EN COMISION-----
                   IF pag_cta.rg_ctas.COD_MONEDA <> v_mon_local THEN
                      v_iva := ROUND((v_comision * v_val_tas_impuesto) / 100,2);
                   else
                      v_iva := ROUND((v_comision * v_val_tas_impuesto) / 100,0);
                   end if;
                   v_cob_neto := v_mto_cobrado;
                 END IF;*/
              END IF;
            end if;
            --valida que la comision no sea mayor al monto cobrado (x mala parametrizacion)
            if v_comision > v_mto_cobrado then
               v_mensaje := 'Valor de la comision '||v_comision||' es superior al monto cobrado '||v_mto_cobrado;
               exit;
               --raise_application_error(-20250,'Valor de la comision es superior al monto cobrado');
            end if;
            --va totalizando los montos para el resumen de remision
            v_tot_comision    := v_tot_comision + nvl(v_comision,0);
            v_tot_iva         := v_tot_iva  + nvl(v_iva,0);
            v_tot_neto        := v_tot_neto + nvl(v_cob_neto,0);
            v_tot_che_nuestro := v_tot_che_nuestro + nvl(v_mto_che_nuestro,0);
            v_tot_che_otros   := v_tot_che_otros + nvl(v_mto_che_otros,0);
            v_tot_efectivo    := v_tot_efectivo + nvl(v_mto_efectivo,0);
            v_tot_debito      := v_tot_debito + nvl(v_mto_debito,0);
            v_cantidad        := v_cantidad + 1;
            ----ACTUALIZA TABLA DE DETALLE----------
            update GE_COB_SERVICIOS
               set mto_COMISION = nvl(v_comision,0),
                   mto_IMPUESTO = nvl(v_iva,0),
                   NRO_REMISION = decode(nvl(servi.SIG_NRO_REMISION,0), 0, 1, servi.SIG_NRO_REMISION),
                   FEC_REMISION = v_fecha
             where COD_SERVICIO = v_cod_servicio
               and TIP_COBRO = v_tip_cobro
               and fecha = v_fec_cobro
               and HORA = v_hor_cobro
               and FEC_REMISION is null
               and NRO_REMISION is null
               and MONTO = v_mto_cobrado
               and rowid = v_registro;
         END LOOP;
         close importe;
         if v_mensaje is not null then
            exit;
         end if;
         ------------------------------------------
         -- ACTUALIZA REGISTROS RECHAZADOS   --
         Update GE_COB_SERVICIOS
            set NRO_REMISION = decode(nvl(servi.SIG_NRO_REMISION,0), 0, 1, servi.SIG_NRO_REMISION),
                FEC_REMISION = v_fecha
          where FEC_REMISION is null
            and NRO_REMISION is null
            and ESTADO = 'E'
            and COD_SERVICIO = v_cod_servicio
            and (fecha <= p_fec_hasta or p_fec_hasta is null);
         -----ACTUALIZAR LA TABLA GE_COB_SER_PARAMETROS----
         update GE_COB_SER_PARAMETROS
            set FEC_ULT_REMISION = v_fecha,
                SIG_NRO_REMISION = nvl(SIG_NRO_REMISION,1)+1
          where COD_SERVICIO = v_cod_servicio;
         -----INSERTA CABECERA EN GE_COB_SERVICIOS_RES----
         v_nro_remito := nvl(servi.SIG_NRO_REMISION,0);
         if v_nro_remito = 0 then
            v_nro_remito := 1;
         end if;
         v_referencia := null;
         if v_tip_cob_cabecera = 'A' then
            begin
            select referencia
              into v_referencia
              from ge_cob_servicios_cab x
             where x.cod_servicio = v_cod_servicio
               and x.fecha = v_fec_proceso;
            exception
               when others then
                  --raise_application_error(-20000,' Cod. Serv '||v_cod_servicio||' fecha '||v_fec_proceso);
                  v_referencia := null;
            end;
         end if;
         --INSERTAR EL RESUMEN DE LA REMISION
         insert into GE_COB_SERVICIOS_RES
           (COD_SERVICIO, FEC_REMISION, NRO_REMISION, CANTIDAD,
            COD_MONEDA, TOT_MONTO, TOT_DEBITO, TOT_EFECTIVO, TOT_CHE_NUE_BANCO,
            TOT_CHE_OTR_BANCO, TOT_COMISION, TOT_IMPUESTO, VAL_TAS_COMISION,
            VAL_TAS_IMPUESTO, COD_OFI_ORIGEN, REFERENCIA)
         values
           (v_cod_servicio, v_fecha, v_nro_remito, v_cantidad,
            v_mon_cta_servicio, v_tot_neto, v_tot_debito, v_tot_efectivo, v_tot_che_nuestro,
            v_tot_che_otros, nvl(v_tot_comision,0), nvl(v_tot_iva,0), v_val_tas_cargo,
            v_val_tas_impuesto, v_ofi_origen, v_referencia);
         --
         if v_cod_servicio = fug_obt_pardinamico('COD_SER_SOFIA') then
            -- se debe enviar mail
            it_mail.mail(fug_obt_dir_correo,
            'mhellemans@itbank.com.py,mcarisimo@itbank.com.py,hkauss@itbank.com.py',
            'Remision Nro '||v_nro_remito||' de Pago de Despachos Aduaneros',
            'A continuacion se detallan los datos de la Remision a realizar al la D.N.A: '||CHR(10)||CHR(10)||
            'Fecha de Remision '||v_fecha||chr(10)||
            'Nro.de Remision   '||v_nro_remito||chr(10)||
            'Cantidad          '||v_cantidad||chr(10)||
            'Total a Remitir   '||v_cod_moneda||' '||v_tot_neto||chr(10)||CHR(10)||
            'Puede imprimir los Detalles de los Cobros a traves de la opcion: '||chr(10)||
            'Informes->Cobros de Servicios->Cobros Remitidos-Detallado '||chr(10)||chr(10)||
            'Atentamente.'
            );
         end if;
         v_nro_secuencia := 0;
--         v_hora   := TO_CHAR(SYSDATE,'HH24:MI:SS');
         -- Para grabar por cada registro procesado y sus movimientos la misma hora
         v_hora := pag_gen.FU_OBT_SIG_SEGUNDO(v_hora);
         --si hay comision
         /* RI : 24/02/2010 : No se genera el movimientos de comision para ANDE,ESSAP y COPACO
           porque estos ya se generan junto con el proceso de cobro del serivicio */
        If v_des_servicio like '%ANDE%'
        or v_des_servicio like '%ESSAP%'  
        or v_des_servicio like '%COPACO%' then
           null;
        else   
          IF nvl(v_comision,0)!= 0 then 
            ----------DEBITO POR LA COMISION--------------------
            --verificar si tiene saldo para realizar el debito
            pag_cta.PR_VER_OPERACION(servi.nro_cuenta,
                                   servi.cod_transaccion,
                                   servi.COD_MODULO,
                                   servi.COD_MODALIDAD,
                                   'D',
                                   v_mon_cta_servicio,
                                   v_tot_comision + v_tot_iva,
                                   v_ofi_origen,
                                   v_mod_cta,
                                   v_mad_cta,
                                   v_est_cta,
                                   v_sal_disponible,
                                   v_procesa,
                                   503);
            -- Si se produjo un error
            If pag_cta.fu_obt_cod_error() <> 0 or v_procesa = 'N' then
               raise_application_error(-20120,'Verif. Deb. '||pag_cta.g_cod_error||'-'||pag_cta.G_MSJ_ERROR);
            end if;
            --realizar el debito de la cuenta x la comision
            v_nro_secuencia := v_nro_secuencia +1;
            pag_cta.pr_act_operacion( servi.nro_cuenta,             --P_NRO_CUENTA
                                    v_hora,                       --P_HORA
                                    'D',                             --P_TIP_MOVIMIENTO
                                    v_mon_cta_servicio,       --P_COD_MONEDA
                                    v_tot_comision,                  --P_MONTO
                                    servi.cod_tra_comision,           --P_COD_TRA_PADRE
                                    servi.cod_tra_comision,                             --P_COD_TRANSACCION
                                    v_nro_remito,   --nro_remision      --P_NRO_DOCUMENTO
                                    null,                            --P_COTIZACION
                                    v_ofi_origen,                   --P_COD_OFI_ORIGEN
                                    servi.cod_modulo,            --P_COD_MOD_PADRE
                                    servi.cod_modalidad,         --P_COD_MAD_PADRE
                                    NULL,                            --P_COD_TASA
                                    NULL,                            --P_VAL_TASA
                                    'Comision Servicio: '||v_cod_servicio,  --P_CONCEPTO
                                    'S',                             --P_EMI_AVISO
                                    v_nro_secuencia,                     --P_NRO_SECUENCIA
                                    v_fecha);                 --P_FEC_VALOR
            -- Si se produjo un error
            If pag_cta.fu_obt_cod_error() <> 0 or v_procesa = 'N' then
               raise_application_error(-20140,'Deb.comis. '||pag_cta.g_cod_error||'-'||pag_cta.G_MSJ_ERROR);
            end if;
            --realizar el debito x el impuesto
            If  nvl(v_tot_iva,0) > 0 then
              v_nro_secuencia := v_nro_secuencia +1;
              pag_cta.pr_act_operacion( servi.nro_cuenta,             --P_NRO_CUENTA
                                      v_hora,                       --P_HORA
                                      'D',                             --P_TIP_MOVIMIENTO
                                      v_mon_cta_servicio,       --P_COD_MONEDA
                                      v_tot_iva,                  --P_MONTO
                                      v_cod_tra_impuesto,           --P_COD_TRA_PADRE
                                      v_cod_tra_impuesto,                             --P_COD_TRANSACCION
                                      v_nro_remito,    --nro_remision     --P_NRO_DOCUMENTO
                                      null,                            --P_COTIZACION
                                      v_ofi_origen,                   --P_COD_OFI_ORIGEN
                                      servi.cod_modulo,            --P_COD_MOD_PADRE
                                      servi.cod_modalidad,         --P_COD_MAD_PADRE
                                      NULL,                            --P_COD_TASA
                                      NULL,                            --P_VAL_TASA
                                      'Impuesto Servicio: '||v_cod_servicio,  --P_CONCEPTO
                                      'S',                             --P_EMI_AVISO
                                      v_nro_secuencia,                     --P_NRO_SECUENCIA
                                      v_fecha);                 --P_FEC_VALOR
              -- Si se produjo un error
              If pag_cta.fu_obt_cod_error() <> 0 or v_procesa = 'N' then
               raise_application_error(-20150,'Deb.impues. '||pag_cta.g_cod_error||'-'||pag_cta.G_MSJ_ERROR);
              end if;
            end if;  
            --actualizar movimientos con el cod_servicio para poder reversar
            update ge_movimientos
               set nro_documento2 = servi.cod_servicio
             where fecha = v_fecha
               and hora  = v_hora
               and cod_usuario = user;
         END IF;
       END IF;  
      END LOOP;--datoser
      close datoser;
      if v_mensaje is not null then
      	 exit;
      end if;
   END LOOP;--detalle
   close detalle;
   if v_mensaje is not null then
      raise_application_error(-20200,v_mensaje);
   end if;
EXCEPTION
  WHEN others THEN
     if sqlcode <= -20000 then
        raise;
     else
        raise_application_error(-20110,'Proc.Remision '||sqlerrm);
     end if;
END;
/

