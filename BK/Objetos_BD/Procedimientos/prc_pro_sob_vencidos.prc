CREATE OR REPLACE PROCEDURE IT.PRC_PRO_SOB_VENCIDOS
 (P_NRO_CUENTA      IN GE_CUENTAS.NRO_CUENTA%TYPE default null,
  P_NRO_DOCUMENTO   IN GE_MOVIMIENTOS.NRO_DOCUMENTO%TYPE default null,
  P_CAU_CANCELACION IN CC_CTA_CORRIENTES.COD_CAU_CANCELACION%TYPE default null,
  P_CONCEPTO        IN GE_MOVIMIENTOS.CONCEPTO%TYPE default null
 )
 IS
  v_impuesto      number(18,2);
  v_interes       number(18,2);
  v_tot_debito    number(18,2);
  v_fcdehoy       date;
  v_nro_secuencia ge_movimientos.nro_secuencia%type :=1;
  v_hora          ge_movimientos.hora%type;
  v_nvo_cuenta    ge_cuentas.nro_cuenta%type;
  v_cod_persona   ba_personas.cod_persona%type;
  v_dia_sob       number(10);
  v_cod_can       number(10);
  v_val_tasa      ge_ope_vencidas.val_tasa%type;

  cursor sobregiros is
    select cta.nro_cuenta,res.can_dias,res.sit_deuda,cta.cod_modulo,cta.cod_modalidad,
           cta.cod_oficina,cta.denominacion,cta.sal_total, cta.sal_bloqueado, cta.sal_retenido,
           cta.mto_cre_pendientes,cta.mto_deb_pendientes,cta.mto_cre_a_confirmar,cta.tas_personalizada,
           cta.aut_pendiente, cta.tra_prohibida,cta.cod_moneda,
           cta.cta_combinada,cta.reg_firma,res.max_atraso,res.pro_atraso
      from cc_sobregiros_res res,
           cc_cta_corrientes cta
     where res.can_dias(+) >= decode(p_nro_cuenta,null,v_dia_sob,res.can_dias(+))
       and cta.nro_cuenta = nvl(p_nro_cuenta,res.nro_cuenta)
       and res.nro_cuenta(+) = cta.nro_cuenta
       and cta.sal_total < 0
       and cta.estado <> 'C';

  cursor rel_cta(p_cuenta varchar2) is
    select cod_persona,dig_verificador,cod_oficina,cod_modulo,cod_modalidad,relacion
      from ge_cta_clientes
     where nro_cuenta = p_cuenta;
begin
   --Obtener el parametro de cantidad de dias
   v_dia_sob := fug_obt_pardinamico('DIA_SOB_VEN');
   v_cod_can := nvl(P_CAU_CANCELACION,fug_obt_pardinamico('COD_CAU_CAN_SOBREGIRO'));
   v_fcdehoy := pag_cal.fu_obt_fec_actual(4);
   v_hora    := to_char(sysdate,'hh24:mi:ss');
   --Obtener la(s) cuenta(s) que pasa(ran) a sobregiros vencidos
   for cta in sobregiros loop
     If p_nro_cuenta is not null then --cuando es manual
       if  nvl(cta.sal_bloqueado, 0) > 0 then
       	 raise_application_error(-20000,'La cuenta tiene saldo bloqueado');
       elsIf nvl(cta.sal_retenido, 0) > 0 then
         raise_application_error(-20000,'La cuenta tiene saldo retenido');
       elsif nvl(cta.mto_cre_pendientes, 0) > 0 then
         raise_application_error(-20000,'La cuenta tiene créditos fuera de hora');
       elsif nvl(cta.mto_deb_pendientes, 0) > 0 then
         raise_application_error(-20000,'La cuenta tiene débitos fuera de hora');
       elsif nvl(cta.mto_cre_a_confirmar, 0) > 0 then
         raise_application_error(-20000,'La cuenta tiene créditos fuera de hora a confirmar');
       elsif  cta.cta_combinada = 'S' Then
         raise_application_error(-20000,'La cuenta participa en cuenta combinada');
       End if;
     End if;
     If (p_nro_cuenta is null and
        nvl(cta.sal_bloqueado,0) = 0 and
        nvl(cta.sal_retenido, 0) = 0 and
        nvl(cta.mto_cre_pendientes, 0) = 0 and
        nvl(cta.mto_deb_pendientes, 0) = 0 and
        nvl(cta.mto_cre_a_confirmar, 0) = 0 and  --cuando es automatico
        cta.cta_combinada = 'N') or
        p_nro_cuenta is not null Then --cuando es manual
        --recuperar interes e impuesto para acreditar luego
        pac_sob.PR_PRO_LIQ_SOB(cta.nro_cuenta,
                       'N', --(N) no va a procesar, sólo calcula
                       v_impuesto,
                       v_interes);
       v_tot_debito := abs(cta.sal_total)+nvl(v_impuesto,0)+nvl(v_interes,0);
       --Realizar la liquidacion del sobregiro
       prc_liq_sobregiros(cta.nro_cuenta);
       --Credito a la cuenta
       pag_cta.pr_act_operacion(cta.nro_cuenta,
       						  v_hora,--HORA
       						  'C',
       						  cta.cod_moneda,
       						  v_tot_debito,
       						  602,--COD_TRA_PADRE
       						  602,
       						  nvl(p_nro_documento,cta.nro_cuenta),
       						  NULL,                      --COTIZACION
       						  cta.cod_oficina,     --cod_ofi_origen
       						  4,     --cod_mod_padre
      						  41,  --cod_mad_padre
      						  null,                      --cod_tasa
      						  null,                      --val_tasa
      						  nvl(p_concepto,'Traspaso a sobregiro vencido'),
      						  'N',                       --emi_aviso
      						  v_nro_secuencia,
      						  trunc(v_fcdehoy));
       if pag_cta.fu_obt_cod_error() <> 0 then
          raise_application_error(-20001,pag_cta.fu_obt_cod_error()||  ' - '|| pag_cta.fu_obt_msj_error());
       End if;

       --Actualizar la causa de cancelación
       update cc_cta_corrientes
          set cod_cau_cancelacion = v_cod_can
        where nro_cuenta = cta.nro_cuenta;

       --Pasar al estado cancelado
       pag_cta.PR_ACT_ESTADO(cta.nro_cuenta,'C', v_fcdehoy,v_hora,nvl(p_nro_documento,cta.nro_cuenta));

       --Obtener el nvo nro de cuenta
       v_nvo_cuenta := fug_obt_sig_nro_cuenta(cta.cod_modulo,
                                              cta.cod_modalidad,
                                              cta.cod_oficina,
                                              cta.cod_moneda,
                                              v_cod_persona);
       --Obtener el valor de la tasa
       v_val_tasa := fug_obt_val_tasa(cta.cod_modulo,
                                      cta.cod_modalidad,
                                      cta.cod_oficina,
                                      cta.nro_cuenta,
                                      cta.cod_moneda,
                                      0, --monto
                                      cta.tas_personalizada,
                                      NULL, --cod_tasa
                                      550, --Transaccion de sobregiro
                                      v_fcdehoy);

       --Inserta el registro operacion vencida
       insert into ge_ope_vencidas(cod_modulo,cod_modalidad,cod_oficina,nro_cuenta,
                                   nro_cta_origen,cod_moneda,denominacion,fec_apertura,
                                   estado,fec_cam_estado,mto_origen,sal_total,reg_firma,
                                   dia_atr_inicial,dia_atraso,fec_ini_mora,val_tasa,max_atraso,pro_atraso)
                           values (4,49,cta.cod_oficina,v_nvo_cuenta,cta.nro_cuenta,cta.cod_moneda,
                                   cta.denominacion,v_fcdehoy,'V',v_fcdehoy,v_tot_debito,
                                   v_tot_debito,cta.reg_firma,cta.can_dias,cta.can_dias,v_fcdehoy-nvl(cta.can_dias,0),
                                   v_val_tasa,cta.max_atraso,cta.pro_atraso);
       --- Insertar relacion cliente cuentas
       for rel in rel_cta(cta.nro_cuenta) loop
         insert into ge_cta_clientes
           (cod_persona, nro_cuenta, dig_verificador,
            cod_oficina, cod_modulo, cod_modalidad, relacion)
         values
           (rel.cod_persona, v_nvo_cuenta, rel.dig_verificador,
            rel.cod_oficina, rel.cod_modulo, rel.cod_modalidad, rel.relacion);
       end loop;

     End if;
   end loop;
exception
  when others then
    If sqlcode <= -20000 then
      raise;
    else
      raise_application_error(-20001,'Error: En el proceso de sobregiros vencidos... '||sqlerrm);
    End if;
end;
/

