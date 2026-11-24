CREATE OR REPLACE PROCEDURE IT.prl_con_transferencia
(p_nro_transferencia in lc_transferencias.nro_ref_externa%type,
 p_cod_oficina in number,
 p_hora in varchar2,
 p_cod_moneda in varchar2,
 p_nro_caja in number,
 p_tip_pago in varchar2,
 p_nro_documento in varchar2,
 p_nro_operacion out varchar2,
 p_cod_mad_padre OUT NUMBER)

/*Procedimiento que permite confirmar una transferencia recibida del exterior,
  acreditando en la cuenta del cliente o pagando en efectivo en la Caja.
  parámetros:
  p_nro_transferencia -> el nro de referencia externa que identifica a la transferencia
  p_cod_oficina       -> oficina del usuario
  p_hora              -> hora para generar movimientos
  p_cod_moneda        -> moneda en que se realiza el pago de la transferencia
  p_nro_caja          -> si es en efectivo para actualizar movimientos
  p_tip_pago          -> 'C' crédito en cuenta, 'E' efectivo caja.
  p_nro_documento     -> nro de documento del beneficiario, si se ingresa en caja para actualizar la transferencia
  p_nro_operacion     -> Retorna el nro de operación para poder imprimir el comprobante en la caja
*/
is
v_mon_pago           lc_transferencias.cod_moneda%type;
v_cod_moneda         lc_transferencias.cod_moneda%type;
v_cta_credito        lc_transferencias.nro_cta_referencia%type;
v_monto              lc_transferencias.monto%type;
v_tip_ope_cpra       lc_tip_operaciones.cod_tip_operacion%type;
v_tip_ope_vta        lc_tip_operaciones.cod_tip_operacion%type;
v_afe_pos_cpra       lc_tip_operaciones.afe_posicion%type;
v_afe_lim_cpra       lc_tip_operaciones.afe_limite%type;
v_caj_cpra           lc_tip_operaciones.caja%type;
v_tip_val_cpra       lc_tip_operaciones.tip_valor%type;
v_mod_ori_cpra       lc_tip_operaciones.cod_mod_origen%type;
v_tra_ope_cpra       lc_tip_operaciones.cod_transaccion%type;
v_mad_hij_cpra       lc_tip_operaciones.cod_mad_hijo%type;
v_cod_tra_ope_cpra   lc_tip_operaciones.cod_transaccion%type;
v_cod_tra_cargo1     lc_tip_operaciones.cod_tra_cargo1%type;
v_cod_tra_cargo2     lc_tip_operaciones.cod_tra_cargo2%type;
v_cod_tra_cargo3     lc_tip_operaciones.cod_tra_cargo3%type;
v_tip_apl_cpra       lc_tip_ope_oficinas.tip_aplicacion%type;
v_cod_rub_cpra       lc_tip_ope_oficinas.cod_rubro%type;
v_cod_tip_ref_cpra   lc_tip_ope_oficinas.cod_tip_referencia%type;
v_des_ope_cpra       lc_tip_operaciones.descripcion%type;
v_ope_bcp_cpra       lc_tip_operaciones.cod_tip_ope_bcp%type;
v_cot_compra         ge_cotizaciones.val_conversion%type;
v_cot_venta          ge_cotizaciones.val_conversion%type;
v_mto_cargo1         ge_movimientos.monto%type;
v_cod_tasa_ini       ge_movimientos.cod_tasa%type;
v_val_tasa_ini       ge_movimientos.val_tasa%type;
v_equ_compra         ge_movimientos.mto_equ_local%type;
v_cod_rub_transferencia varchar2(20);
v_des_cargo          ge_transacciones.descripcion%type;
v_afe_pos_vta        lc_tip_operaciones.afe_posicion%type;
v_afe_lim_vta        lc_tip_operaciones.afe_limite%type;
v_caj_vta            lc_tip_operaciones.caja%type;
v_tip_val_vta        lc_tip_operaciones.tip_valor%type;
v_mod_ori_vta        lc_tip_operaciones.cod_mod_origen%type;
v_tra_ope_vta        lc_tip_operaciones.cod_transaccion%type;
v_mad_hij_vta        lc_tip_operaciones.cod_mad_hijo%type;
v_cod_tra_ope_vta    lc_tip_operaciones.cod_transaccion%type;
v_tip_apl_vta        lc_tip_ope_oficinas.tip_aplicacion%type;
v_cod_rub_vta        lc_tip_ope_oficinas.cod_rubro%type;
v_cod_tip_ref_vta    lc_tip_ope_oficinas.cod_tip_referencia%type;
v_des_ope_vta        lc_tip_operaciones.descripcion%type;
v_ope_bcp_vta        lc_tip_operaciones.cod_tip_ope_bcp%type;
v_nro_operacion      number;
v_nro_ref_cpra       lc_transferencias.nro_referencia%type;
v_nro_ref_vta        lc_transferencias.nro_referencia%type;
v_mad_operacion      lc_transferencias.cod_modalidad%type;
v_fec_actual         date := pag_cal.fu_obt_fec_actual(7); -- fecha de hoy
v_nro_secuencia      ge_movimientos.nro_secuencia%type:=0;
v_cod_per_benef      lc_transferencias.cod_per_beneficiario%type;
v_mon_local          ge_movimientos.cod_moneda%type := pag_gen.FU_OBT_MON_LOCAL;
v_mon_fuerte         ge_movimientos.cod_moneda%type := pag_gen.FU_OBT_MON_FUERTE;
v_cta_cambios        lc_cta_cambios.nro_cuenta%type;
v_lim_utilizado      lc_cta_cambios.mto_limite%type;
v_cod_retencion      ge_movimientos.cod_retencion%type;
v_fec_fin_retencion  date;
v_est_cta            lc_cta_cambios.estado%type;
v_cod_ofi_cta        lc_cta_cambios.cod_oficina%type;
v_msj                varchar2(500);
v_est_mvto           ge_movimientos.estado%type :='N';--mvto. principal
v_est_mvto_resto     ge_movimientos.estado%type :='N';--otros movimientos
v_mod_cta_cre        ge_cuentas.cod_modulo%type;
v_mad_cta_cre        ge_cuentas.cod_modalidad%type;
v_ofi_cta_cre        ge_cuentas.cod_oficina%type;
v_tra_impuesto       ge_movimientos.cod_transaccion%type;
v_impuesto           ge_movimientos.monto%type;
v_mov_impuesto       ge_movimientos.monto%type;
v_cod_tasa           number;
v_val_tasa           number;
v_mto_venta          number;
v_nro_documento      lc_transferencias.nro_doc_beneficiario%type;
v_bco_corresponsal   ge_movimientos.cod_banco%type;
v_nro_cta_bancaria   ge_movimientos.nro_cuenta%type;
v_ofi_cta_bancaria   ge_cuentas.cod_oficina%type;

r_gmovi              ge_movimientos%rowtype;
v_hora               ge_movimientos.hora%type := nvl(p_hora, to_char(sysdate,'hh24:mi:ss'));
v_tip_pago           varchar2(1) := nvl(p_tip_pago,'C'); --si no viene es C
--caja
v_cod_transaccion    number(4) := 221;
v_cod_modulo         number(3) := 9;
v_cod_modalidad      number(3) := 91;
v_msj_respuesta      long := ''; -- sin errores
-----
v_redondeo_ml        number(2) := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',7,null,v_mon_local);
v_redondeo           number(2);
v_cod_tra_pad_aux    ge_transacciones.cod_transaccion%type;
v_tie_cam_estado varchar2(1) ;
v_hab_mt199  ge_par_dinamicos.val_parametro%type := nvl(fug_obt_pardinamico('HAB_MT199_GPII',null,null,null,null),'N');
v_respuesta varchar2(3000);
v_gpi  varchar2(10):='N';
v_cod_tra_pad_auxiliar  ge_transacciones.cod_transaccion%type;
v_cod_mod_pad_aux       ge_transacciones.cod_modulo%type;
v_cod_mad_pad_aux       ge_transacciones.cod_modalidad%type;
v_rut_arc_mt199      varchar2(50) := FUG_OBT_PARDINAMICO('RUT_MSJ_SWIFT_199'); 
v_ofi_matriz         ba_oficinas.cod_oficina%type := fug_obt_ofi_matriz;
/*recupera cta límite del cliente */
FUNCTION lf_obt_cta_cliente RETURN varchar2 IS
v_nro_cuenta lc_cta_cambios.nro_cuenta%type;
BEGIN
  SELECT B.NRO_CUENTA
    INTO v_nro_cuenta
    FROM LC_CTA_CAMBIOS B, GE_CTA_CLIENTES  A
   WHERE ESTADO in('N','A')
     AND A.NRO_CUENTA = B.NRO_CUENTA
     AND RELACION = 'P'
     AND A.COD_MODULO = 7
     AND A.COD_MODALIDAD = 70
     AND A.COD_PERSONA = v_cod_per_benef
     AND ROWNUM = 1;--en teoria debe haber un solo límite x cliente,siempre en USD
   return v_nro_cuenta;
EXCEPTION
  WHEN NO_DATA_FOUND THEN
       --recuperar par dinamico para cuenta bolsa x la oficina
       v_nro_cuenta:= fug_obt_pardinamico('CTA_CAM_CLI_TEMPORAL',NULL,NULL,NULL,p_cod_oficina);
       return v_nro_cuenta;
  WHEN OTHERS THEN
       raise_application_error(-200800,'Al recup.Cta Límite Cliente '||v_cod_per_benef||sqlerrm);
END;

-- Procedimiento interno para generar movimiento y act. de control de caja
procedure lp_gen_transaccion
    (p_tip_movimiento in varchar2,
     p_tip_monto      in varchar2,
     p_cod_moneda     in varchar2,
     p_importe        in number,
     p_nro_secuencia  in number)   is
  v_mto_cheque        number(18,2) := 0;
  v_mto_che_ntro_bco  number(18,2) := 0;
  v_mto_efectivo      number(18,2) := 0;
begin
  -- evaluo el tipo de valor
  if p_tip_monto = 'E' then
     v_mto_efectivo := p_importe;
  elsif p_tip_monto ='C' then
     v_mto_che_ntro_bco := p_importe;
  else
     v_mto_cheque   := p_importe;
  end if;
  if p_tip_movimiento = 'D' then  -- compra
    -- sumar a los saldos  -- Actualizo el control de caja
     update cj_controles
        set tot_che_otr_bco = nvl(tot_che_otr_bco,0) + nvl(v_mto_cheque,0),
            tot_che_nue_bco = nvl(tot_che_nue_bco,0) + nvl(v_mto_che_ntro_bco,0),
            sal_che_otr_bco = nvl(sal_che_otr_bco,0) + nvl(v_mto_cheque,0),
            sal_actual = nvl(sal_actual,0) + nvl(v_mto_efectivo,0),
            tot_debitos = nvl(tot_debitos,0) + nvl(v_mto_efectivo,0),
            can_debitos = nvl(can_debitos,0) + decode(v_mto_efectivo,0,0,1),
            estado = 1 -- abierto
      where nro_caja   = to_number(p_nro_caja)
        and cod_moneda = p_cod_moneda
        and fecha      = v_fec_actual;
  else
     -- se resta del saldo del cajero -- Actualizo el control de caja
     update cj_controles
        set sal_actual = nvl(sal_actual,0) - nvl(v_mto_efectivo,0),
            tot_creditos = nvl(tot_creditos,0) + nvl(v_mto_efectivo,0),
            can_creditos = nvl(can_creditos,0) + 1,
            estado = 1 -- abierto
      where nro_caja   = to_number(p_nro_caja)
        and cod_moneda = p_cod_moneda
        and fecha      = v_fec_actual;
  end if;
    -- genero el movimiento por la operación compra/venta
  insert into cj_movimientos
       (fecha, hora, cod_usuario, nro_secuencia,
        cod_tra_padre, cod_mod_padre, cod_mad_padre,
        cod_oficina, cod_moneda, nro_caja,
        nro_documento,  monto, tip_monto, tipo)
  values
       (v_fec_actual, v_hora, user, p_nro_secuencia,
        v_cod_transaccion, v_cod_modulo, v_cod_modalidad,
        p_cod_oficina, p_cod_moneda, to_number(p_nro_caja),
        v_nro_operacion, p_importe,
        p_tip_monto, p_tip_movimiento); /* es D-ebito o C-redito */
        /*E-fectivo/C-heq Ntro.Bco /O-Cheq.Otr.Bco(1) /T-Otr.Bco Tarde(2) /S-Otr.Bco(3) PLoc /X-Otr.Bco(3) PExt*/
end lp_gen_transaccion;
----

begin
   v_mon_pago := p_cod_moneda;
   --recuperar los datos de la transferencia
   begin
     select nro_cta_referencia, monto, cod_moneda, cod_per_beneficiario, nro_doc_beneficiario, cod_bco_corresponsal,
            cod_tip_referencia, nro_referencia, cod_rubro, nvl(gpi,'N')
       into v_cta_credito, v_monto, v_cod_moneda, v_cod_per_benef, v_nro_documento, v_bco_corresponsal,
            v_cod_tip_ref_cpra, v_nro_ref_cpra, v_cod_rub_transferencia,v_gpi
       from lc_transferencias
      where nro_ref_externa = p_nro_transferencia
        and cod_modalidad = 75
        and estado not in ('OK','AN','DE');
   exception
      when no_data_found then
           raise_application_error(-20000,'Transf. '||p_nro_transferencia||' inexistente o estado inválido.');
      when others then
           raise_application_error(-20001,'Recup.Transf '||p_nro_transferencia||'.'||sqlerrm);
   end;
   v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',7,null,v_cod_moneda);
   --obtener datos de la cuenta de crédito
   if v_cta_credito is not null then
      pag_cta.PR_OBT_CUENTA(v_cta_credito);
      v_mon_pago := pag_cta.FU_OBT_MON_CUENTA;
      if pag_cta.fu_obt_cod_error() <> 0 then
         raise_application_error(-20003,'Recup.Cta.Crédito '||v_cta_credito||'-'||pag_cta.fu_obt_msj_error());
      end if;
      v_mod_cta_cre  := pag_cta.g_ctas.cod_modulo;
      v_mad_cta_cre  := pag_cta.g_ctas.cod_modalidad;
      v_ofi_cta_cre  := pag_cta.g_ctas.cod_oficina;
   end if;
   --si es crédito en cuenta
   if v_tip_pago = 'C' then
      if v_cta_credito is null then
         raise_application_error(-20004,'Transf. '||p_nro_transferencia||' no posee Cuenta a Acreditar.');
      end if;
   elsif v_tip_pago = 'E' then -- si es en efectivo
      if p_cod_moneda is null then
         raise_application_error(-20005,'Moneda de Pago no definida.');
      end if;
   else
      --otro tipo de pago error
      raise_application_error(-20006,'Tipo de pago inválido');
   end if;
   --obtener cotizacion
   if v_tip_pago = 'C' then
     if v_mon_pago <> v_cod_moneda then
      v_cot_compra := pal_cam.FU_OBT_COT_COM_CHEQUE(v_cod_moneda);--CRODEEVO-8 --07/04/2017
     else
      v_cot_compra := pal_cam.FU_OBT_COT_COMPRA(v_cod_moneda); 
     end if;
   else
      v_cot_compra := pal_cam.FU_OBT_COT_COMPRA(v_cod_moneda);
   end if;
   --ver qué operación hacer de acuerdo a la moneda
   if p_cod_moneda = v_mon_local or v_mon_pago = v_mon_local then
      --compra
      v_tip_ope_cpra := 15; --compra de transferencia
      v_mad_operacion := 71;
      v_cot_venta     := 1;
   else
      if v_mon_pago <> v_cod_moneda then
         --arbitraje
         v_tip_ope_cpra := 59; --arbitraje -compra transferencia
         if v_tip_pago = 'E' then
            v_tip_ope_vta := 41;
         else
           v_tip_ope_vta  := 45; --arbitraje -venta dep.en cuenta m/e
         end if;
         v_mad_operacion := 73;
        if v_tip_pago = 'C' then
          v_cot_venta := pal_cam.FU_OBT_COT_VEN_CHEQUE(v_mon_pago);--CRODEEVO-8 --07/04/2017
        else
          v_cot_venta := pal_cam.FU_OBT_COT_VENTA(v_mon_pago);
        end if;
      else
         --canje
         v_tip_ope_cpra := 89; --canje -compra transferencia
         if v_tip_pago = 'E' then
            v_tip_ope_vta := 71;
         else
            v_tip_ope_vta  := 75; --canje -venta dep.en cuenta m/e
         end if;
         v_mad_operacion := 74;
         v_cot_venta := v_cot_compra;
      end if;
   end if;
   p_cod_mad_padre := v_mad_operacion;

   --recuperar los datos de la operación, de compra debe haber
   begin
      select afe_posicion, afe_limite, caja, tip_valor, cod_mod_origen,
             cod_transaccion, cod_mad_hijo, cod_tra_cargo1, cod_tra_cargo2, cod_tra_cargo3,
             tip_aplicacion, cod_rubro, descripcion, a.cod_tip_ope_bcp
        into v_afe_pos_cpra, v_afe_lim_cpra, v_caj_cpra, v_tip_val_cpra, v_mod_ori_cpra,
             v_cod_tra_ope_cpra, v_mad_hij_cpra, v_cod_tra_cargo1, v_cod_tra_cargo2, v_cod_tra_cargo3,
             v_tip_apl_cpra, v_cod_rub_cpra, v_des_ope_cpra, v_ope_bcp_cpra
        from lc_tip_ope_oficinas b, lc_tip_operaciones a
       where b.cod_tip_operacion = a.cod_tip_operacion
         and b.cod_moneda = v_cod_moneda --moneda de la transf
         and b.cod_oficina = p_cod_oficina --oficina del usuario
         and a.cod_tip_operacion = v_tip_ope_cpra --operación compra
         and nivel = 1;
      --buscar la operación de venta
      if v_tip_ope_vta is not null then
         select afe_posicion, afe_limite, caja, tip_valor, cod_mod_origen,
                cod_transaccion, cod_mad_hijo, --sin cargos
                tip_aplicacion, cod_rubro, cod_tip_referencia, descripcion, a.cod_tip_ope_bcp
           into v_afe_pos_vta, v_afe_lim_vta, v_caj_vta, v_tip_val_vta, v_mod_ori_vta,
                v_cod_tra_ope_vta, v_mad_hij_vta,
                v_tip_apl_vta, v_cod_rub_vta, v_cod_tip_ref_vta, v_des_ope_vta, v_ope_bcp_vta
           from lc_tip_ope_oficinas b, lc_tip_operaciones a
          where b.cod_tip_operacion = a.cod_tip_operacion
            and b.cod_moneda = v_cod_moneda --moneda de la transf
            and b.cod_oficina = p_cod_oficina --oficina del usuario
            and a.cod_tip_operacion = v_tip_ope_vta --operación venta
            and nivel = 1;
      end if;
   exception
       when no_data_found then
            raise_application_error(-20007,'Tipo de Operación inválido. '||v_tip_ope_cpra||' - '||v_tip_ope_vta);
   end;
   v_equ_compra := round(v_monto * v_cot_compra,v_redondeo_ml);

   --obtiene cta de cambios del cliente
   v_cta_cambios := lf_obt_cta_cliente;

   --recup. cargo 1
   if v_cod_tra_cargo1 is not null then
      begin
         --si la cta de cambios no es la bolsa y no tiene persona identificada, llamar x nro cuenta, sino x persona
         if v_cta_cambios <> fug_obt_pardinamico('CTA_CAM_CLI_TEMPORAL',NULL,NULL,NULL,p_cod_oficina) or
            v_cod_per_benef is null then
            pal_cam.pr_obt_cargos(v_cod_tra_cargo1, v_mad_operacion, v_cod_moneda, v_monto, v_equ_compra,
                                  p_cod_oficina, v_cta_cambios, null, v_des_cargo,
                                  v_mto_cargo1, v_cod_tasa, v_val_tasa);
         elsif v_cod_per_benef is not null then
         --DYDMR-5313 Se pasa la cta_crédito como parametro para obtener la tasa personalizada (ALV-NOV/2016)
            pal_cam.pr_obt_cargos(v_cod_tra_cargo1, v_mad_operacion, v_cod_moneda, v_monto, v_equ_compra,
                                  p_cod_oficina, v_cta_credito, v_cod_per_benef, v_des_cargo,
                                  v_mto_cargo1, v_cod_tasa, v_val_tasa);
         end if;
      exception
         when others then
              raise_application_error(-20008,'Recup.Cargo. Oper. '||v_tip_ope_cpra||' - Trans.'||v_cod_tra_cargo1);
      end;
   end if;
   v_mto_cargo1 := round(nvl(v_mto_cargo1,0), v_redondeo_ml);
   --Se almacena valor original del cargo y la tasa
   v_cod_tasa_ini  := v_cod_tasa;
   v_val_tasa_ini  := v_val_tasa;
   --
   v_cod_tasa      :=NULL;
   v_val_tasa      :=NULL;
   --
   if nvl(v_mto_cargo1,0) > 0  then
      --Verificar si tienen impuestos asociados
      pal_cam.pr_obt_impuestos(v_cod_tra_cargo1, v_mad_operacion, v_mto_cargo1,
                               p_cod_oficina, v_tra_impuesto, v_impuesto,
                               v_cod_tasa, v_val_tasa);
      --Se guarda el impuesto del movimiento para luego utilizarlo en el desgloze del IVA si aplica.
      v_mov_impuesto := nvl(v_impuesto,0);
      if v_impuesto is not null then
         --Inicializo de nuevo las variables de retorno
         v_cod_tasa      :=NULL;
         v_val_tasa      :=NULL;
         v_impuesto      :=NULL;
         --
         -- Validar si tiene personalizada la tasa correspondiente al impuesto
         if v_cod_per_benef is not null then
            pal_cam.pr_obt_cargos(v_tra_impuesto, v_mad_operacion, v_mon_local,
                                  v_mto_cargo1, v_mto_cargo1, p_cod_oficina, null,
                                  v_cod_per_benef, v_des_cargo, v_impuesto,
                                  v_cod_tasa, v_val_tasa);
         end if;
      end if;
      -- Si tiene personalizada la tasa correspondiente al impuesto se debita la misma del cargo
      if v_impuesto is not null and nvl(v_val_tasa,0) = 0 then
         v_mto_cargo1 :=  v_mto_cargo1 - v_mov_impuesto;
      end if;
   end if;
   --*

   v_mto_venta  := round((v_equ_compra - v_mto_cargo1) / v_cot_venta,v_redondeo);

   --buscar cuenta corresponsal
   if v_tip_apl_cpra in ('A','L') then
      begin
        select nro_cuenta, cod_oficina
          into v_nro_cta_bancaria, v_ofi_cta_bancaria
          from cc_cta_bancarias
         where cod_moneda = v_cod_moneda
           and estado = 'N'
           and cod_modalidad = 45
           and cod_banco = v_bco_corresponsal;
      exception
        when no_data_found then
          raise_application_error(-20009,'Corresponsal inexistente');
        when too_many_rows then
          raise_application_error(-20010,'Varios Correponsales definidos');
        when others then
          raise_application_error(-20011,'Recup.Corresp.'|| sqlerrm);
      end;
   end if;

   begin pre_ini_aplicacion; pae_cnf.g_cod_modulo:=7; end;
   --asignar nro de recibo a la operación
   begin
      v_nro_operacion := fug_obt_lla_pardinamico('NRO_RECIBO', 7, v_mad_operacion, v_cod_moneda, p_cod_oficina)+1;
      prg_act_par_dinamico('NRO_RECIBO',7, v_mad_operacion, v_cod_moneda, p_cod_oficina, v_nro_operacion);
      --asigno nro_referencia, se utiliza secuencia para evitar bloqueos
      if v_tip_ope_vta is not null then
         v_nro_ref_vta := fue_obt_sig_secuencia('S_NRO_REF_'||lpad(v_cod_tip_ref_vta,3,0)||'');
      end if;
   exception
      when others then
         if sqlcode <= -20000 then
            raise_application_error(-20012,'Asigna Nro.Oper. '||sqlerrm);
         end if;
   end;
   --generar movimientos
   r_gmovi.cod_mod_padre  := 7;
   r_gmovi.cod_modulo     := 7; --modulo operac o cuenta
   r_gmovi.cod_mad_padre  := v_mad_operacion;
   r_gmovi.cod_oficina    := v_ofi_matriz;--31; /*26.10.2009 FB. El DB del rub. ctble se debe hacer en la oficina 31 */--P_COD_OFICINA;
   r_gmovi.cod_ofi_origen := P_COD_OFICINA; --ofi del usuario
   r_gmovi.cod_usuario    := user;
   r_gmovi.hora           := v_hora;
   r_gmovi.fecha          := v_fec_actual;
   r_gmovi.fec_valor      := v_fec_actual;
   r_gmovi.reversado      := 'N';
   r_gmovi.emi_aviso      := 'S';
   r_gmovi.estado         := 'N';
   r_gmovi.nro_cuenta     := null;
   r_gmovi.cod_banco      := null;
   v_nro_secuencia        := v_nro_secuencia + 1;
   r_gmovi.nro_secuencia  := v_nro_secuencia;
   r_gmovi.cod_persona    := v_cod_per_benef;

   --genera movimiento principal
   r_gmovi.cod_tra_padre   := v_cod_tra_ope_cpra;
   if v_tip_apl_cpra in ('A','L') then
      r_gmovi.cod_modulo      := 4;
      r_gmovi.cod_modalidad   := 45; --corresponsal
      r_gmovi.cod_transaccion := 196;
      r_gmovi.nro_cuenta      := v_nro_cta_bancaria;
      r_gmovi.cod_banco       := v_bco_corresponsal;
      r_gmovi.cod_oficina     := v_ofi_cta_bancaria; --AAP- Si es una cuenta Bancaria, vuelvo a asignar cod_oficina para que tome la de la cuenta
   else
      r_gmovi.cod_modalidad   := v_mad_hij_cpra;
      r_gmovi.cod_transaccion := v_cod_tra_ope_cpra;
   end if;
   r_gmovi.nro_caja        := p_nro_caja;
   r_gmovi.NRO_DOCUMENTO2 := v_nro_ref_cpra;
--   r_gmovi.NRO_DOCUMENTO4 := v_cod_transaccion; --transac.de caja para poder autorizar
   r_gmovi.COD_REF_CAMBIO := v_cod_tip_ref_cpra;
   r_gmovi.cod_moneda      := v_cod_moneda; --moneda de la transf
   r_gmovi.monto           := v_monto; --monto de la transf
   r_gmovi.nro_documento   := v_nro_operacion;
   r_gmovi.concepto        := 'Conf.Transf.'||trim(p_nro_transferencia);--substr(nvl(v_nom_completo,p_nombre),1,35);
   r_gmovi.tip_mov_rubro   := null;
--     v_tip_monto := 'E'; --efectivo
   if v_tip_apl_cpra in ('B') then --afecta cta.ctable
      r_gmovi.cod_rubro    := v_cod_rub_cpra;
      r_gmovi.tip_mov_rubro := 'D';
   elsif v_cod_rub_transferencia is not null then
      r_gmovi.cod_rubro    := v_cod_rub_transferencia;
      r_gmovi.tip_mov_rubro := 'D';
   else
      r_gmovi.cod_rubro    := null;
      r_gmovi.tip_mov_rubro := null;
   end if;
   r_gmovi.cotizacion      := v_cot_compra;
   r_gmovi.mto_equ_local   := round(v_equ_compra,v_redondeo_ml);
   r_gmovi.cod_bco_central := v_ope_bcp_cpra;
   r_gmovi.cod_tip_ope_cambio:= v_tip_ope_cpra;
   --genera el movimiento
   PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi);
   r_gmovi.cod_oficina := P_COD_OFICINA; -- AAP Vuelvo a asignar la oficina que tenia, por si se generan otros movimientos
   --actualiza la cuenta corresponsal
   if v_tip_apl_cpra in ('A','L') then
      PAG_CTA.PR_ACT_SAL_CTA(v_nro_cta_bancaria,r_gmovi.cod_modalidad,'C',v_fec_actual,v_hora,v_monto,0,0,null,'N');
       IF PAG_CTA.FU_OBT_COD_ERROR() <> 0 THEN
         raise_application_error(-20000,'Act.Sal.Corresponsal '||PAG_CTA.fu_obt_msj_error);
      END IF;
   end if;
   --actualiza la posición si corresponde
   PAL_CAM.PR_ACT_POSICIONES(v_tip_ope_cpra, v_cod_moneda, pal_cam.fu_obt_ofi_cambio(P_cod_oficina),
                             v_monto, round(v_equ_compra,v_redondeo_ml), v_ope_bcp_cpra);

   r_gmovi.cod_banco       := null;
   r_gmovi.cod_rubro       := null;
   r_gmovi.tip_mov_rubro   := null;
   r_gmovi.cod_modulo      := 7;

   if v_tip_ope_vta is not null then --es arb o canje
      --generar movimientos x la venta :efectivo/crédito en cuenta //
      if v_cta_credito is not null then
          -- Actualiza la Cuenta Crédito / Destino
          pag_cta.pr_act_operacion(v_cta_credito,
                         v_hora,                     --HORA
                         'C',
                         v_mon_pago,                 --Moneda de la Operación
                         v_mto_venta,                --monto
                         v_cod_tra_ope_vta,          -- COD_TRA_PADRE (Compra divisas en efectivo)
                         602,                        -- COD_TRA_HIJO CREDITO CUENTA CLIENTE
                         v_nro_operacion,            --nro_documento
                         v_cot_venta,                --COTIZACION, los pagos son en moneda local
                         p_cod_oficina,              --cod_ofi_origen
                         7,                            --cod_mod_padre
                         r_gmovi.cod_mad_padre,      --o abmc.modalidad       --cod_mad_padre
                         null,                       --cod_tasa
                         null,                       --val_tasa
                         'Conf.Transf.-Crédito Cta',
                         'S',                        --emi_aviso
                         v_nro_secuencia,
                         v_fec_actual,
                         null,
                         null,
                         v_equ_compra - v_mto_cargo1);
          if pag_cta.fu_obt_cod_error() <> 0 then
             raise_application_error(-20013,'Crédito. '||pag_cta.fu_obt_msj_error());
          end if;
          --actualizar el movimiento con el tip_ope_cambio
          begin
            -- Verificar si tiene cambio de estado --
            v_tie_cam_estado := 'N';
            select decode(nvl(count(*),0),0,'N','S')
               into v_tie_cam_estado
               from ge_movimientos a
               where fecha = v_fec_actual
               and hora = v_hora
               and cod_usuario = user
               and nro_cuenta = v_cta_credito
               and a.cod_transaccion = 425
               and a.concepto = 'Cambio de Estado'
               and a.nro_secuencia = 2;
            if nvl(v_tie_cam_estado,'N') = 'S' then
                update ge_movimientos a
                    set  a.nro_secuencia = -999
               where fecha =v_fec_actual
                   and hora = v_hora
                   and cod_usuario = user
                   and nro_cuenta = v_cta_credito
                   and a.cod_transaccion = 425
                   and a.concepto = 'Cambio de Estado'
                   and a.nro_secuencia = 2;
            end if;
            -------------------------------------------------
            update ge_movimientos
               set cod_tip_ope_cambio = v_tip_ope_vta,
                   nro_documento2 = v_nro_ref_vta,
                   cod_ref_cambio = v_cod_tip_ref_vta,
                   cod_bco_central = v_ope_bcp_vta,
                   nro_secuencia = decode(nvl(v_tie_cam_estado,'N'),'N',nro_secuencia,2)
             where fecha =v_fec_actual
               and hora = v_hora
               and cod_usuario = user
               and nro_cuenta = v_cta_credito
               and cod_tra_padre = v_cod_tra_ope_vta
               and cod_mod_padre = 7
               and cod_mad_padre = r_gmovi.cod_mad_padre
               and cod_modulo = v_mod_cta_cre
               and cod_modalidad = v_mad_cta_cre
               and cod_moneda =v_mon_pago
               and monto = v_mto_venta;
               ------------------------------------------------
              if nvl(v_tie_cam_estado,'N') = 'S' then
                    update ge_movimientos a
                        set  a.nro_secuencia = 3
                   where fecha =v_fec_actual
                       and hora = v_hora
                       and cod_usuario = user
                       and nro_cuenta = v_cta_credito
                       and a.cod_transaccion = 425
                       and a.concepto = 'Cambio de Estado'
                       and a.nro_secuencia = -999;
                end if;
          ------------------------------------------------
          exception
            when others then
                 raise_application_error(-20014,'Act.Mvto.Crédito. '||substr(sqlerrm,1,400));
          end;
      else --efectivo caja
         --movimiento x el efectivo
         v_nro_secuencia            := v_nro_secuencia + 1;
         r_gmovi.nro_secuencia      := v_nro_secuencia;
         r_gmovi.cod_tra_padre      := v_cod_tra_ope_vta;
         r_gmovi.cod_modalidad      := v_mad_hij_vta;
         r_gmovi.cod_moneda         := v_mon_pago;--moneda del pago
         r_gmovi.cod_tip_ope_cambio := v_tip_ope_vta;
         r_gmovi.cod_transaccion    := 740;
         r_gmovi.tip_mov_rubro      := null;
         r_gmovi.cod_rubro          := null;
         r_gmovi.nro_cuenta         := null;
         r_gmovi.monto              := v_mto_venta; --ver los cargos
         r_gmovi.nro_documento      := v_nro_operacion;
         r_gmovi.concepto           := 'Conf.Transf. - Caja';--substr(nvl(v_nom_completo,p_nombre),1,35);
         r_gmovi.cod_tasa           := null;
         r_gmovi.val_tasa           := null;
         r_gmovi.nro_caja           := p_nro_caja;
         r_gmovi.NRO_DOCUMENTO2     := v_nro_ref_vta;
    --   r_gmovi.NRO_DOCUMENTO4     := v_cod_transaccion; --transac.de caja para poder autorizar
         r_gmovi.COD_REF_CAMBIO     := v_cod_tip_ref_vta;
         r_gmovi.nro_documento      := v_nro_operacion;
    --     v_tip_monto := 'E'; --efectivo
         r_gmovi.cotizacion        := v_cot_venta;
         r_gmovi.mto_equ_local     := v_equ_compra - v_mto_cargo1;
         r_gmovi.cod_bco_central   := v_ope_bcp_vta;
         -- verifico los decimales del importe y autorización -- solo por el crédito
         --si es venta se hace x el principal, si es compra se hace x la forma de pago
         /*if v_cod_mad_operacion = 71 then --compra
           v_msj_respuesta := fuj_val_importe(v_tip_mov_rubro,'E',v_mon_local,r_gmovi.monto,null);--ver la transacción a pasar
           if v_msj_respuesta is not null then
              v_cod_respuesta := '005';  -- error
           end if;
         end if;*/
         --genera movimiento
         PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi);
         --actualizar caja
         lp_gen_transaccion('C',
                            'E', -- fijo Efectivo
                             r_gmovi.cod_moneda,
                             r_gmovi.monto,
                             r_gmovi.nro_secuencia);
      end if;--cta cliente

      --actualiza la posición si corresponde
      PAL_CAM.PR_ACT_POSICIONES(v_tip_ope_vta, v_mon_pago, pal_cam.fu_obt_ofi_cambio(P_cod_oficina),
                                v_mto_venta, round(v_equ_compra,v_redondeo_ml), v_ope_bcp_vta);
   end if;

   --recuperar datos de la cta de cambios
   pag_cta.pr_obt_cuenta(v_cta_cambios);
   v_est_cta := pag_cta.g_ctas.estado;
   v_cod_ofi_cta := pag_cta.g_ctas.cod_oficina;
   if pag_cta.fu_obt_cod_error() <> 0 then
      raise_application_error(-20015,'Recup.Cta.Cambios '||v_cta_cambios||'-'||pag_cta.fu_obt_msj_error());
   end if;
   --solo si afecta límite
   if v_afe_lim_cpra <> 'S' THEN
      v_lim_utilizado := 0;
   else
      --si moneda de la operación diferente al límite convertir
      if v_cod_moneda <> v_mon_fuerte then
         v_lim_utilizado:= pal_cam.FU_CON_MON_A_MONEDA(v_cod_moneda,v_mon_fuerte,v_monto);--para q busque la correspondiente
      else
         v_lim_utilizado:= v_monto;
      end if;
   end if;
   --actualización de límite, sólo si afecta recupera retención
   begin
     select estado, cod_oficina
       into v_est_cta, v_cod_ofi_cta
       from lc_cta_cambios
      where nro_cuenta = v_cta_cambios
        for update of estado;
     update lc_cta_cambios
        set mto_utilizado = nvl(mto_utilizado,0) + nvl(v_lim_utilizado,0),
            fec_ult_movimiento = v_fec_actual,
            estado = decode(estado,'A','N',estado),
            fec_cam_estado =decode(estado,'A',v_fec_actual,fec_cam_estado)
      where lc_cta_cambios.nro_cuenta = v_cta_cambios;
     IF v_afe_lim_cpra = 'S' THEN --solo si afecta límite
        --obtiene retención
        pal_cam.pr_obt_retencion(v_tip_ope_cpra, null, null,
               v_mon_fuerte, p_cod_oficina,v_COD_RETENCION, v_FEC_FIN_RETENCION);
     end if;
     --genera movimientos
     v_nro_secuencia         := v_nro_secuencia + 1;
     r_gmovi.nro_secuencia   := v_nro_secuencia;
     r_gmovi.cod_modulo      := 7;
     r_gmovi.cod_modalidad   := 70;
     r_gmovi.cod_oficina     := v_cod_ofi_cta;
     r_gmovi.cod_moneda      := v_mon_fuerte;
     r_gmovi.cod_tra_padre   := v_cod_tra_ope_cpra; --
     r_gmovi.cod_transaccion := 760;
     r_gmovi.monto           := v_lim_utilizado;
     r_gmovi.nro_documento   := v_nro_operacion;
     r_gmovi.COD_REF_CAMBIO := v_cod_tip_ref_cpra;
     if v_cod_per_benef is not null then --persona existente
        r_gmovi.NRO_DOCUMENTO2  := v_cod_per_benef;
        r_gmovi.REFERENCIA      := null;
     else
        r_gmovi.REFERENCIA      := NVL(v_nro_documento,p_nro_documento);
         r_gmovi.NRO_DOCUMENTO2  := null;
     end if;
     r_gmovi.concepto        := 'Operación Cambios Límite';
     r_gmovi.cod_rubro       := NULL;
     r_gmovi.nro_cuenta      := v_cta_cambios;
     r_gmovi.tip_mov_rubro   := null;
     r_gmovi.cod_persona     := v_cod_per_benef;
     if v_cod_moneda <> v_mon_fuerte then
        r_gmovi.cotizacion   := pag_gen.fu_obt_cotizacion(v_mon_fuerte);--cotizacion del límite en la moneda fuerte
     else
        r_gmovi.cotizacion := v_cot_compra;
     end if;
     r_gmovi.mto_equ_local   := ROUND(NVL(v_lim_utilizado,0)*r_gmovi.cotizacion,v_redondeo_ml);
     r_gmovi.cod_bco_central := v_ope_bcp_cpra;
     r_gmovi.COD_RETENCION   := v_COD_RETENCION;
     r_gmovi.FEC_FIN_RETENCION:= v_FEC_FIN_RETENCION;
     r_gmovi.cod_tip_ope_cambio:= null;
     PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi);
     r_gmovi.REFERENCIA      := null;
     --movimiento x el cambio de estado de la cuenta si corresponde
     if v_est_cta = 'A' then
        v_nro_secuencia := v_nro_secuencia + 1;
        r_gmovi.nro_secuencia  := v_nro_secuencia;
        r_gmovi.cod_modulo      := 7;
        r_gmovi.cod_modalidad   := 70;
        r_gmovi.cod_oficina     := v_cod_ofi_cta;
        r_gmovi.cod_moneda      := v_mon_fuerte;
        r_gmovi.fec_valor       := v_fec_actual;
        
        --DYDMR-10209 - Confirmación de Transferencias Recibidas
        ---reservar valores en variables auxiliares
        v_cod_tra_pad_auxiliar  := r_gmovi.cod_tra_padre;
        v_cod_mod_pad_aux       := r_gmovi.cod_mod_padre;
        v_cod_mad_pad_aux       := r_gmovi.cod_mad_padre;
        
        r_gmovi.cod_tra_padre   := 401;
        r_gmovi.cod_mod_padre   := 7;
        r_gmovi.cod_mad_padre   := 70;
        
        --DYDMR-10209 - Confirmación de Transferencias Recibidas
        --volcar valores de auxiliares en variables globales
        r_gmovi.cod_tra_padre   := v_cod_tra_pad_auxiliar;
        r_gmovi.cod_mod_padre   := v_cod_mod_pad_aux;
        r_gmovi.cod_mad_padre   := v_cod_mad_pad_aux;
        
        
        r_gmovi.cod_transaccion := 401;
        r_gmovi.monto           := null;
        r_gmovi.nro_documento   := null;
        r_gmovi.NRO_DOCUMENTO2  := null;
        r_gmovi.concepto        := 'Cambio de Estado ';
        r_gmovi.est_cuenta      := 'N';
        r_gmovi.cod_rubro       := NULL;
        r_gmovi.nro_cuenta      := v_cta_cambios;
        r_gmovi.tip_mov_rubro   := null;
        r_gmovi.cotizacion      := null;
        r_gmovi.mto_equ_local   := null;
        r_gmovi.cod_bco_central := null;
        r_gmovi.COD_RETENCION   := null;
        r_gmovi.FEC_FIN_RETENCION :=null;
        r_gmovi.COD_REF_CAMBIO   := null;
        r_gmovi.cod_tip_ope_cambio := null;
        PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi);
      end if;
    EXCEPTION
      WHEN OTHERS THEN
        raise_application_error(-20016,'Actualiza límite. '||sqlerrm);
    END;
   r_gmovi.COD_RETENCION     := null;
   r_gmovi.FEC_FIN_RETENCION := null;
   r_gmovi.cod_modalidad     := v_mad_hij_cpra;
   --gastos
   -- Si no tiene personalizada la tasa correspondiente al impuesto se debita la misma del cargo
   if v_mov_impuesto is not null and nvl(v_val_tasa,0) <> 0 then
      v_mto_cargo1 :=  v_mto_cargo1 - v_mov_impuesto;
   end if;
   if nvl(v_mto_cargo1,0) > 0  then
      if v_cod_tra_cargo1 is not null then
          -- Aumento la secuencia
         v_nro_secuencia           := v_nro_secuencia + 1;
         r_gmovi.nro_secuencia     := v_nro_secuencia;
         r_gmovi.cod_oficina       := p_cod_oficina;
         r_gmovi.cod_moneda        := v_mon_local;
         v_cod_tra_pad_aux         := r_gmovi.cod_tra_padre;
         r_gmovi.cod_tra_padre     := v_cod_tra_cargo1;
         r_gmovi.cod_transaccion   := v_cod_tra_cargo1;
         r_gmovi.monto             := v_mto_cargo1;
         r_gmovi.nro_documento     := v_nro_operacion;
         r_gmovi.nro_cuenta        := null;
         r_gmovi.concepto          := 'Cargos de Cambios';
         r_gmovi.COD_TASA          := v_cod_tasa_ini;
         r_gmovi.VAL_TASA          := v_val_tasa_ini;
         r_gmovi.tip_mov_rubro     := null;
         r_gmovi.cod_tip_ope_cambio:=null;
         r_gmovi.cotizacion        := null;
         r_gmovi.mto_equ_local     := null;
         r_gmovi.cod_ref_cambio    := v_cod_tip_ref_cpra;
         r_gmovi.nro_documento2    := v_nro_ref_cpra;
         r_gmovi.cod_bco_central := v_ope_bcp_cpra;
         -- Fecha: 08/08/2014.
         -- Requerimiento: CNFIRGTR-2.
         IF v_tip_pago = 'C' THEN
            r_gmovi.referencia     := v_cta_credito;
         ELSE
            r_gmovi.referencia     := NULL;
         END IF;
         PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi);
         r_gmovi.cod_tra_padre     := v_cod_tra_pad_aux;
         -- Fecha: 08/08/2014.
         -- Requerimiento: CNFIRGTR-2.
         r_gmovi.referencia        := NULL;
          -- genero movimiento x el impuesto si no tiene exonerado
          if v_mov_impuesto is not null and nvl(v_val_tasa,0) <> 0 then
            v_nro_secuencia         := v_nro_secuencia + 1;
            r_gmovi.nro_secuencia   := v_nro_secuencia;
            v_cod_tra_pad_aux       := r_gmovi.cod_tra_padre;
            r_gmovi.cod_tra_padre   := v_cod_tra_cargo1;
            r_gmovi.cod_transaccion := v_tra_impuesto;
            r_gmovi.monto           := v_mov_impuesto;
            r_gmovi.COD_TASA        := v_cod_tasa;
            r_gmovi.VAL_TASA        := v_val_tasa;
            r_gmovi.concepto        := 'Impuesto Cargos de Cambios';
            PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi);
            r_gmovi.cod_tra_padre   := v_cod_tra_pad_aux;
         end if;
     end if;
     r_gmovi.cod_tasa     :=null;
     r_gmovi.val_tasa     :=null;
   end if;

   if v_mad_operacion = 71 then --sólo si es compra, todo en moneda local
      --movimiento x la forma de pago:efectivo/crédito en cuenta
      if v_cta_credito is not null then
          -- Actualiza la Cuenta Crédito / Destino
          pag_cta.pr_act_operacion(v_cta_credito,
                         v_hora,--HORA
                         'C',
                         v_mon_local, --Moneda de la Operación
                         nvl(v_equ_compra,0),--menos el cargo y menos el impuesto DR
                         v_cod_tra_ope_cpra,  -- COD_TRA_PADRE (Compra divisas en efectivo)
                         602,  -- COD_TRA_HIJO CREDITO CUENTA CLIENTE
                         v_nro_operacion, --nro_documento
                         null,       --COTIZACION, los pagos son en moneda local
                         p_cod_oficina,      --cod_ofi_origen
                         7,                --cod_mod_padre
                         71,--o abmc.modalidad       --cod_mad_padre
                         null,                       --cod_tasa
                         null,                       --val_tasa
                         'Conf.Transf.-Crédito Cta',
                         'S',                        --emi_aviso
                         v_nro_secuencia,
                         v_fec_actual);
          if pag_cta.fu_obt_cod_error() <> 0 then
             raise_application_error(-20017,'Crédito. '||pag_cta.fu_obt_msj_error());
          end if;


          if nvl(v_mto_cargo1,0) > 0 then  --DYDMR-5271 Se agrega la condición al bloque (ALVD-NOV/2016)

             --DYDMR-7069 --Incidencia SAU - Error cobro IVA transferencia Recibidas
             -- Si no tiene personalizada la tasa correspondiente al impuesto se debita la misma del cargo
             if nvl(v_mov_impuesto,0) > 0 and nvl(v_val_tasa,0) <> 0 then
                v_mto_cargo1 :=  nvl(v_mto_cargo1,0) + nvl(v_mov_impuesto,0);
             end if;
             -- Si tiene personalizada la tasa correspondiente al impuesto se debita la misma del cargo
             if nvl(v_impuesto,0) > 0 and nvl(v_val_tasa,0) = 0 then
               v_mto_cargo1 :=  nvl(v_mto_cargo1,0);
             end if;

            --Debito separado por el Cargo - Resolucion II-BCP
            pag_cta.pr_act_operacion(v_cta_credito,
                           v_hora,--HORA
                           'D',
                           v_mon_local, --Moneda de la Operación
                           nvl(v_mto_cargo1,0),--menos el cargo y menos el impuesto DR --DYDMR-7069
                           v_cod_tra_cargo1,  -- COD_TRA_PADRE (Compra divisas en efectivo)
                           503,  -- COD_TRA_HIJO CREDITO CUENTA CLIENTE
                           v_nro_operacion, --nro_documento
                           null,       --COTIZACION, los pagos son en moneda local
                           p_cod_oficina,      --cod_ofi_origen
                           7,                --cod_mod_padre
                           71,--o abmc.modalidad       --cod_mad_padre
                           null,                       --cod_tasa
                           null,                       --val_tasa
                           'DB Cargo - Impuesto',
                           'S',                        --emi_aviso
                           v_nro_secuencia,
                           v_fec_actual);
            if pag_cta.fu_obt_cod_error() <> 0 then
               raise_application_error(-20017,'Debito. '||pag_cta.fu_obt_msj_error());
            end if;
          end if;
          --actualizar el movimiento con el tip_ope_cambio
          begin
             --Verificar si tiene cambio de estado--
            v_tie_cam_estado := 'N';
            select decode(nvl(count(*),0),0,'N','S')
               into v_tie_cam_estado
               from ge_movimientos a
               where fecha =v_fec_actual
               and hora = v_hora
               and cod_usuario = user
               and nro_cuenta = v_cta_credito
               and a.cod_transaccion = 425
               and a.concepto = 'Cambio de Estado'
               and a.nro_secuencia = 2;
            if nvl(v_tie_cam_estado,'N') = 'S' then
                update ge_movimientos a
                    set  a.nro_secuencia = -999
               where fecha = v_fec_actual
                   and hora = v_hora
                   and cod_usuario = user
                   and nro_cuenta = v_cta_credito
                   and a.cod_transaccion = 425
                   and a.concepto = 'Cambio de Estado'
                   and a.nro_secuencia = 2;
            end if;
            -------------------------------------------------
            update ge_movimientos
               set cod_tip_ope_cambio = 3,
                   nro_documento2 = v_nro_ref_cpra,
                   cod_ref_cambio = v_cod_tip_ref_cpra,
                   cod_bco_central = v_ope_bcp_cpra,
                    nro_secuencia = decode(nvl(v_tie_cam_estado,'N'),'N',nro_secuencia,2)
             where fecha =v_fec_actual
               and hora = v_hora
               and cod_usuario = user
               and nro_cuenta = v_cta_credito
               and cod_tra_padre = v_cod_tra_ope_cpra
               and cod_mod_padre = 7
               and cod_mad_padre = 71
               and cod_modulo = v_mod_cta_cre
               and cod_modalidad = v_mad_cta_cre
               and cod_moneda =v_mon_local
               and monto = v_equ_compra - v_mto_cargo1 - v_mov_impuesto;--se agregó menos el impuesto DR
                 ------------------------------------------------
                if nvl(v_tie_cam_estado,'N') = 'S' then
                      update ge_movimientos a
                          set  a.nro_secuencia = 3
                     where fecha =v_fec_actual
                         and hora = v_hora
                         and cod_usuario = user
                         and nro_cuenta = v_cta_credito
                         and a.cod_transaccion = 425
                         and a.concepto = 'Cambio de Estado'
                         and a.nro_secuencia = -999;
                  end if;
               ------------------------------------------------
          exception
            when others then
                 raise_application_error(-20018,'Act.Mvto.Crédito. '||substr(sqlerrm,1,400));
          end;
      else --efectivo caja
         --movimiento x el efectivo
         v_nro_secuencia            := v_nro_secuencia + 1;
         r_gmovi.nro_secuencia      := v_nro_secuencia;
         r_gmovi.cod_oficina        := p_cod_oficina;
         r_gmovi.cod_moneda         := v_mon_local;
         r_gmovi.cod_tip_ope_cambio := 1;
         r_gmovi.cod_transaccion    := 740;
         r_gmovi.monto              := v_equ_compra - v_mto_cargo1; --ver los cargos
         r_gmovi.nro_documento      := v_nro_operacion;
         r_gmovi.concepto           := 'Conf.Transf. - Caja';
         r_gmovi.nro_cuenta         := null;
         r_gmovi.cod_rubro          := NULL;
         r_gmovi.tip_mov_rubro      := null;
         r_gmovi.cod_tasa           := null;
         r_gmovi.val_tasa           := null;
         r_gmovi.cod_bco_central    := v_ope_bcp_cpra;
         r_gmovi.nro_caja           := p_nro_caja;
         r_gmovi.NRO_DOCUMENTO2     := v_nro_ref_cpra;
         r_gmovi.cotizacion         := null;
         r_gmovi.mto_equ_local      := null;
    --   r_gmovi.NRO_DOCUMENTO4     := v_cod_transaccion; --transac.de caja para poder autorizar
         r_gmovi.COD_REF_CAMBIO     := v_cod_tip_ref_cpra;
         r_gmovi.cod_persona        := v_cod_per_benef;

         -- verifico los decimales del importe y autorización -- solo por el crédito
         --si es venta se hace x el principal, si es compra se hace x la forma de pago
         /*if v_mad_ope_cpra = 71 then --compra
           v_msj_respuesta := fuj_val_importe('C','E',v_mon_local,r_gmovi.monto,null);--ver la transacción a pasar
           if v_msj_respuesta is not null then
              raise_application_error(-20000,'Val.importe '||v_msj_respuesta);
           end if;
         end if;*/
         --genera movimiento
         PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi);
         --actualizar caja
         lp_gen_transaccion('C',
                             'E', -- fijo Efectivo
                             r_gmovi.cod_moneda,
                             r_gmovi.monto,
                             r_gmovi.nro_secuencia);
      end if;--cta cliente
   end if;--compra
   --devolver el nro_operación
   p_nro_operacion := v_nro_operacion;
   --actualizar la transferencia recibida, si no tenía nro documento y carga, actualizar
   update lc_transferencias
      set saldo  = nvl(saldo,0) - v_monto,
          est_anterior = estado,
          estado = 'OK',
          nro_doc_beneficiario = decode(nro_doc_beneficiario,null,p_nro_documento,nro_doc_beneficiario),
          nro_operacion = v_nro_operacion
    where nro_ref_externa = p_nro_transferencia;
    
    --Para GPII se debe llamar a la nueva función para Generar MT199, s esta habilitado 
    IF nvl(v_gpi,'N')='S' and nvl(v_hab_mt199,'N')='S' then
       v_respuesta:= null;
       v_respuesta:= ful_gen_msj_swift_199(p_nro_transferencia, nvl(v_mto_cargo1,0),'S');
       PRL_GEN_ARC_MSJ_SWIFT_199(v_respuesta,v_rut_arc_mt199);
    end if;
    

exception
   when others then
      if sqlcode <= -20000 then
         raise;
      else
         raise_application_error(-20003,'Confir.Transf. '||sqlerrm);
      end if;
end;
/

