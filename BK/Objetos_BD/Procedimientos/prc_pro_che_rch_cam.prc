CREATE OR REPLACE PROCEDURE IT.PRC_PRO_CHE_RCH_CAM(p_cod_oficina in number,
                                                p_cod_moneda in varchar2,
                                                p_reg_pro in out number,
                                                p_reg_err in out number,
                                                p_reg_tot in out number) is
  v_fcdehoy       date := pag_cal.fu_obt_fec_actual(4);
  v_cdofcam       number(3) := fug_obt_ofi_camara(p_cod_oficina);

   ---Datos de la cuenta---
  v_cod_modalidad ge_cuentas.cod_modalidad%type;
   v_nro_cuenta    ge_cuentas.nro_cuenta%type;
  v_procesa       varchar2(1);

  g_error  varchar2(10000) := null;
  g_tiperr varchar2(3);
  g_hora ge_movimientos.hora%type;
  g_wk_nrsecuen ge_movimientos.nro_secuencia%type := 100;

  v_cant_error number(5);
  v_cant_tot   number(5);
  v_es_cambio varchar2(1):='N';
  v_mto_alt_valor ge_par_dinamicos.val_parametro%type;
  v_tip_importe cc_sal_camara.tip_importe%type := 0;

  -- Cursor Principal de Cheques Rechazados a Procesar
  cursor clrch_cur is
     select c.*, c.rowid registro
       from cc_che_rechazados_tmp c
      where nvl(cod_ofi_camara, v_cdofcam) = v_cdofcam
        and nvl(estado, 'P') not in  ('C','E')
        and cod_moneda = p_cod_moneda
        and fec_proceso = v_fcdehoy
        and procesar = 'S'
      order by nro_linea, nro_cuenta;
  ---

  clrch clrch_cur%rowtype;

--Actualizar Maestros
procedure lp_actualizar_maestros is
    v_ingreso varchar2(1);
begin
    v_ingreso := 'N';
    if pag_cta.g_ctas.cod_modalidad IN (31,334) then
       v_ingreso := 'S';
       update ah_cta_vistas set
              sal_total = nvl(sal_total,0) - nvl(clrch.monto,0),
              fec_ult_movimiento = v_fcdehoy,
              hor_ult_movimiento = g_hora
        where cod_modulo    = pag_cta.g_ctas.cod_modulo
          and cod_modalidad = pag_cta.g_ctas.cod_modalidad
          and cod_oficina   = pag_cta.g_ctas.cod_oficina
          and nro_cuenta    = pag_cta.g_ctas.nro_cuenta;
          if sql%notfound then
            raise_application_error(-20099, 'Al actualizar AH_CTA_VISTAS');
          end if;
          --Cambio de Estado si corresponde (de Inactiva a Normal)
          if pag_cta.g_ctas.estado = 'I' then
            pag_cta.pr_set_variables(user, v_fcdehoy, 420, 'N', 'N', g_wk_nrsecuen, 'I', pag_cta.g_ctas.cod_oficina, pag_cta.g_ctas.cod_modulo, pag_cta.g_ctas.cod_modalidad);
            pag_cta.pr_act_estado(pag_cta.g_ctas.nro_cuenta,'N',v_fcdehoy,
                                 g_hora,null);
            g_wk_nrsecuen := nvl(g_wk_nrsecuen,0) + 1;

          end if;
       elsif pag_cta.g_ctas.cod_modalidad in (33,34) then
          v_ingreso := 'S';
          update ah_cta_certificados set
                 sal_total = nvl(sal_total,0) - nvl(clrch.monto,0),
                 fec_ult_movimiento = v_fcdehoy,
                 hor_ult_movimiento =  g_hora
            where cod_modulo    = pag_cta.g_ctas.cod_modulo
              and cod_modalidad = pag_cta.g_ctas.cod_modalidad
              and cod_oficina   = pag_cta.g_ctas.cod_oficina
              and nro_cuenta    = pag_cta.g_ctas.nro_cuenta;
          if sql%notfound then
            raise_application_error(-20099, 'Al actualizar AH_CTA_CERTIFICADOS');
          end if;

          --Cambio de Estado si corresponde
          if pag_cta.g_ctas.estado = 'N' then
            pag_cta.pr_set_variables(user, v_fcdehoy, 420, 'N', 'N', g_wk_nrsecuen, 'A', pag_cta.g_ctas.cod_oficina, pag_cta.g_ctas.cod_modulo, pag_cta.g_ctas.cod_modalidad);
            pag_cta.pr_act_estado(pag_cta.g_ctas.nro_cuenta,'A',v_fcdehoy,
                                 g_hora,null);
            g_wk_nrsecuen := nvl(g_wk_nrsecuen,0) + 1;
          end if;
       elsif pag_cta.g_ctas.cod_modulo = 4 then
          v_ingreso := 'S';
          update cc_cta_corrientes set
                  sal_total = nvl(sal_total,0) - nvl(clrch.monto,0),
                  fec_ult_movimiento = v_fcdehoy,
                  hor_ult_movimiento = g_hora
            where cod_modulo    = pag_cta.g_ctas.cod_modulo
              and cod_modalidad = pag_cta.g_ctas.cod_modalidad
              and cod_oficina   = pag_cta.g_ctas.cod_oficina
              and nro_cuenta    = pag_cta.g_ctas.nro_cuenta;
          if sql%notfound then
            raise_application_error(-20099, 'Al actualizar CC_CTA_CORRIENTES');
          end if;
          --Cambio de Estado si corresponde
          if pag_cta.g_ctas.estado = 'I' then
            pag_cta.pr_set_variables(user, v_fcdehoy, 420, 'N', 'N', g_wk_nrsecuen, 'I', pag_cta.g_ctas.cod_oficina, pag_cta.g_ctas.cod_modulo, pag_cta.g_ctas.cod_modalidad);
            pag_cta.pr_act_estado(pag_cta.g_ctas.nro_cuenta,'N',v_fcdehoy,
                                 g_hora,null);

            g_wk_nrsecuen := nvl(g_wk_nrsecuen,0) + 1;
          end if;
        elsif pag_cta.g_ctas.cod_modulo = 5 then
          v_ingreso := 'S';
        end if;

        --Verificar que haya ingresado en el if...
        if v_ingreso = 'N' then
           raise_application_error(-20099, 'Error en LP_ACTUALIZAR_MAESTROS');
        end if;

end lp_actualizar_maestros;

procedure lp_gen_movimiento is
 r_gmovi ge_movimientos%rowtype;
 v_cod_tra_padre ge_transacciones.cod_transaccion%type := 321;
 v_cod_mod_padre ge_transacciones.cod_modulo%type := 4;
 v_cod_mad_padre ge_transacciones.cod_modalidad%type := 41;
begin
  g_wk_nrsecuen := nvl(g_wk_nrsecuen,0) + 1;

  r_gmovi.cod_usuario     := user;
  r_gmovi.hora             := g_hora;
  r_gmovi.nro_secuencia   := g_wk_nrsecuen;
  r_gmovi.cod_modulo      := pag_cta.g_ctas.cod_modulo;
  r_gmovi.cod_modalidad   := pag_cta.g_ctas.cod_modalidad;
  r_gmovi.cod_oficina     := pag_cta.g_ctas.cod_oficina; --v_cod_oficina;
  r_gmovi.nro_cuenta      := pag_cta.g_ctas.nro_cuenta;
  r_gmovi.cod_tra_padre   := v_cod_tra_padre; --Codigo de Transaccion PADRE
  if clrch.com_directa ='S' then
    r_gmovi.cod_transaccion := 503;
  else
    r_gmovi.cod_transaccion := 522;
  end if;
  r_gmovi.fecha           := v_fcdehoy;
  r_gmovi.fec_valor       := v_fcdehoy;
  r_gmovi.cod_moneda      := pag_cta.g_ctas.cod_moneda;
  r_gmovi.cod_mod_padre   := v_cod_mod_padre;
  r_gmovi.cod_mad_padre   := v_cod_mad_padre;
  r_gmovi.cod_ofi_origen  := clrch.cod_ofi_camara; --v_cod_oficina ;
  r_gmovi.nro_documento   := clrch.nro_cheque;
  r_gmovi.monto           := clrch.monto;
  r_gmovi.cod_banco       := clrch.cod_bco_emisor;
  r_gmovi.cod_causa       := clrch.cod_cau_devolucion;
  r_gmovi.concepto        := 'Cheq.dev.de camara';
  r_gmovi.estado          :='N';
  r_gmovi.reversado       :='N';
  r_gmovi.protegido       :='N';
  r_gmovi.emi_aviso       :='N';
  r_gmovi.estado          :='N';
  pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
exception
  when others then
     raise_application_error(-20099, 'Error en LP_GEN_MOVIMIENTO');
end lp_gen_movimiento;

--Generación de Movimiento Contable
procedure lp_gen_mov_contable is
    v_tpasien ge_tip_asientos.cod_tip_asiento%type;
    r_gmovi ge_movimientos%rowtype;

    v_cod_tra_padre ge_transacciones.cod_transaccion%type:=321;
    v_cod_mod_padre ge_transacciones.cod_modulo%type:=4;
    v_cod_mad_padre ge_transacciones.cod_modalidad%type:=41;

    ---Hago el debito a la cuenta manual y el cred.al del asiento 4/41/522
    cursor op_as is
        select tip_movimiento, cod_rubro
          from ge_tip_asientos
         where cod_tip_asiento  = v_tpasien
           and cod_moneda       = clrch.cod_moneda
           and nvl(cod_sec_contable,'N') = 'N'
           and ind_deudor       = 'N'
           and ind_residente    in ('S','X')
           and tip_movimiento   = 'C'
        union all
        select 'D' tip_movimiento,clrch.cod_rubro
          from dual;
begin
--
  select cod_tip_asiento
    into v_tpasien
    from ge_transacciones
   where cod_modulo      =  v_cod_mod_padre --:variables.wk_cdmodul
     and cod_modalidad   =  v_cod_mad_padre --:variables.wk_cdmodal
     and cod_transaccion = 522;

  if v_tpasien is null then
     raise_application_error(-20099, 'Tipo de asiento nulo: trans.');
  end if;
  for mm in op_as loop
    g_wk_nrsecuen := nvl(g_wk_nrsecuen,0) + 1;
    r_gmovi.cod_usuario         := user;
    r_gmovi.hora                 := g_hora;
    r_gmovi.nro_secuencia       := g_wk_nrsecuen;
    r_gmovi.cod_modulo           := 4; --p_cdmodul;
    r_gmovi.cod_modalidad       := 41; --p_cdmodal;
    if mm.tip_movimiento = 'D' then
      r_gmovi.cod_oficina       :=  clrch.cod_oficina; --v_cod_oficina;
    else
      r_gmovi.cod_oficina       := p_cod_oficina;  --p_cdofior;
    end if;
    r_gmovi.cod_moneda           := clrch.cod_moneda;
    r_gmovi.cod_tra_padre       := v_cod_tra_padre;
    r_gmovi.cod_transaccion     := null; --522;  --No Grabar Código de Transacción p/ Movs. contra Rubros Contables
    r_gmovi.fecha               := v_fcdehoy;
    r_gmovi.fec_valor           := v_fcdehoy;
    r_gmovi.monto                 := clrch.monto;
    r_gmovi.estado               := 'N';
    r_gmovi.emi_aviso           := 'N';
    r_gmovi.concepto             := 'Cheq.dev.de camara';
    r_gmovi.cod_ofi_origen       := p_cod_oficina;  --p_cdofior;
    r_gmovi.cod_mod_padre       := v_cod_mod_padre;
    r_gmovi.cod_mad_padre       := v_cod_mad_padre;
    r_gmovi.reversado           := 'N';
    r_gmovi.protegido           := 'N';
    r_gmovi.tip_mov_rubro        := mm.tip_movimiento;
    r_gmovi.cod_rubro           := mm.cod_rubro;
    r_gmovi.cod_causa           := clrch.cod_cau_devolucion;
    r_gmovi.cod_banco           := clrch.cod_bco_emisor;
    pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
  end loop;

end lp_gen_mov_contable;

--Actualizar saldos de Cámara
procedure lp_act_camara is
begin
  v_mto_alt_valor := to_number(nvl(fug_obt_pardinamico('MTO_CHE_RET_CERO',null,null,clrch.cod_moneda),0));
  IF clrch.monto >= v_mto_alt_valor THEN
     v_tip_importe := 1;
  ELSE
     v_tip_importe := 0;
  END IF;
  --Actualizar los cheques rechazados en la tabla de totales
  update cc_sal_camara
     set sis_che_dev_camara = nvl(sis_che_dev_camara,0) + nvl(clrch.monto,0)
   where cod_ofi_camara = clrch.cod_ofi_camara
     and cod_moneda     = clrch.cod_moneda
     and fecha          = v_fcdehoy
     and tip_importe    = v_tip_importe;
  if sql%notfound then
     insert into cc_sal_camara
       (cod_ofi_camara,cod_moneda,fecha,sis_che_dev_camara,tip_importe)
     values
       (clrch.cod_ofi_camara,clrch.cod_moneda,v_fcdehoy,
        clrch.monto,v_tip_importe);
  end if;
exception
  when others then
     raise_application_error(-20099, 'Error en LP_ACT_CAMARA');
end;

--Insertar en CC_CHE_RECHAZADOS
procedure lp_ins_cc_che_rechazados is

begin

  insert into cc_che_rechazados
    (fec_proceso,nro_cheque,cta_libradora,monto,cod_bco_emisor,
     cod_bco_receptor,nro_cuenta,cod_cau_devolucion,cod_ofi_camara,
     cod_usuario,tip_debito,cod_oficina,cod_rubro,cob_cargos,estado,procesar,
     msj_error,cod_moneda,cod_cau_dev_bcp,com_directa,nro_linea,cod_submotivo, cod_submotivo_det)--
  values
    (clrch.fec_proceso,clrch.nro_cheque,clrch.cta_libradora,clrch.monto,clrch.cod_bco_emisor,
     clrch.cod_bco_receptor,clrch.nro_cuenta,clrch.cod_cau_devolucion,clrch.cod_ofi_camara,
     clrch.cod_usuario,clrch.tip_debito,clrch.cod_oficina,clrch.cod_rubro,clrch.cob_cargos,'C',clrch.procesar,
     clrch.msj_error,clrch.cod_moneda,clrch.cod_cau_dev_bcp,clrch.com_directa,clrch.nro_linea,clrch.cod_submotivo, clrch.cod_submotivo_det);
exception
  when others then
     raise_application_error(-20099, 'Error en LP_INS_CC_CHE_RECHAZADOS');
end;

--Insertar en CC_CHE_RECHAZADOS_DET
PROCEDURE lp_ins_cc_che_rechazados_det IS
  v_longitud        number(2);
  v_posicion        number(2) := 1;
  v_cod_cau_dev     cc_che_rechazados_det.cod_cau_devolucion%type;
  v_cod_cau_dev_bcp number(2);
BEGIN
  DELETE cc_che_rechazados_det d
   WHERE d.fec_proceso = clrch.fec_proceso
     AND d.nro_cheque  = clrch.nro_cheque
     AND d.cta_libradora = clrch.cta_libradora
     AND d.cod_bco_emisor = clrch.cod_bco_emisor;
  v_longitud := nvl(round(length(clrch.cod_cau_dev_bcp_det)/2), 0);        
  FOR i in 1..v_longitud LOOP
      v_cod_cau_dev_bcp := substr(clrch.cod_cau_dev_bcp_det, v_posicion, 2);
      BEGIN
        SELECT MAX(z.cod_causa)
          INTO v_cod_cau_dev
          FROM ge_par_causales z
         WHERE z.parametro = 'COD_DEV_BCP' 
           AND z.val_parametro = v_cod_cau_dev_bcp;
      EXCEPTION
         WHEN OTHERS THEN
           v_cod_cau_dev := null;   
      END;  
      IF v_cod_cau_dev IS NOT NULL THEN
        INSERT INTO cc_che_rechazados_det
          (fec_proceso, nro_cheque, cta_libradora, cod_bco_emisor, 
           cod_cau_devolucion, cod_cau_dev_bcp)
        VALUES
          (clrch.fec_proceso, clrch.nro_cheque, clrch.cta_libradora, clrch.cod_bco_emisor,
           v_cod_cau_dev, v_cod_cau_dev_bcp);
      END IF;     
      v_posicion := v_posicion + 2;   
  END LOOP;   
EXCEPTION
  WHEN OTHERS THEN
     raise_application_error(-20099, 'Error en LP_INS_CC_CHE_RECHAZADOS_DET. - '||sqlerrm);
END;

--Actualizar Estado del cheque
procedure lp_act_est_cheque is
   v_fec_envio date;
   v_fec_remitido date;
begin

    --Obtener la ultima fecha de envio
    select max(fecha)
      into v_fec_envio
      from cc_che_enviados
     where cod_banco = clrch.cod_bco_emisor
       and estado <> 'D'
       and nro_cheque = clrch.nro_cheque;

    ---
    select max(fecha)
      into v_fec_remitido
      from cc_che_remitidos
     where cod_banco = clrch.cod_bco_emisor
       and nro_cheque = clrch.nro_cheque
       and cod_cau_devolucion is null
       and cod_oficina = v_cdofcam;

    --CC_CHE_REMITIDOS
    -- Intento marcar en cheques remitidos
    update cc_che_remitidos
       set cod_cau_devolucion = clrch.cod_cau_devolucion,
           dev_com_directa = clrch.com_directa
     where cod_banco = clrch.cod_bco_emisor
       and nro_cheque = clrch.nro_cheque
       and fecha = (select max(fecha) --Xq puede haber varias devoluciones
                      from cc_che_remitidos
                     where cod_banco = clrch.cod_bco_emisor
                       and nro_cheque = clrch.nro_cheque);
      if sql%notfound then
         raise_application_error(-20099, 'Al actualizar CC_CHE_REMITIDOS '||clrch.nro_cheque);
      end if;
    --CC_CHE_ENVIADOS
    if v_fec_envio is not null and (v_fec_envio >= v_fec_remitido or v_fec_remitido is null) then
      update cc_che_enviados
         set estado = 'D',
             cod_cau_devolucion = clrch.cod_cau_devolucion
       where cod_banco = clrch.cod_bco_emisor
         and nro_cheque = clrch.nro_cheque
         and estado in ('E','C','I','L')
         and fecha = (select max(fecha) --Xq puede haber varias devoluciones
                        from cc_che_enviados
                       where cod_banco = clrch.cod_bco_emisor
                         and nro_cheque = clrch.nro_cheque
                         and estado in ('E','C','I','L'));

        if sql%notfound then
           raise_application_error(-20099, 'Al actualizar CC_CHE_ENVIADOS '||clrch.nro_cheque);
        end if;
    end if;
end;

--Compensación Directa
procedure lp_compensacion is
  v_nro_cuenta     cc_cta_bancarias.nro_cuenta%type;
  v_cod_modalidad  ge_modalidades.cod_modalidad%type;
begin
  prc_obt_cta_bancaria(clrch.cod_bco_emisor,
                  clrch.cod_moneda,
                  p_cod_oficina,
                  v_nro_cuenta,
                  v_cod_modalidad);

  If v_nro_cuenta is not null then
    g_wk_nrsecuen := g_wk_nrsecuen + 1;
    pag_cta.pr_act_operacion
                             (v_nro_cuenta
                             ,g_hora
                             ,'C'
                             ,clrch.cod_moneda
                             ,clrch.monto
                             ,321
                             ,602
                             ,clrch.nro_cheque
                             ,NULL
                             ,p_cod_oficina  --:variables.wk_cdofici
                             ,4              --:variables.wk_cdmodul
                             ,41             --:variables.wk_cdmodal
                             ,null
                             ,null
                             ,null
                             ,'N'
                             ,g_wk_nrsecuen
                             ,null
                             ,null
                             ,null);
   if pag_cta.fu_obt_cod_error() <> 0 then
      raise_application_error(-20099, pag_cta.fu_obt_cod_error()||  ' - '|| pag_cta.fu_obt_msj_error());
   end if;
  else
    raise_application_error(-20099, 'Cta. Bancaria no habilitada para el Banco :'||clrch.cod_bco_emisor);
  End if;

exception
  when others then
       raise_application_error(-20099,'Error en LP_COMPENSACION');
end lp_compensacion;

/****************************
 **   BLOQUE PRINCIPAL     **
 ****************************/
begin

  p_reg_pro := 0;
  p_reg_err := 0;
  p_reg_tot := 0;

  if clrch_cur%isopen then
     close clrch_cur;
  end if;
  open clrch_cur;

  g_hora := fug_ini_hora(sysdate,'hh24:mi:ss');

  --Ciclo de Proceso
  <<proceso>>
  loop
    fetch clrch_cur into clrch;
    exit when clrch_cur%notfound;

      v_procesa := 'S';
      pag_cta.g_ctas := null;
      g_error := null;
      g_tiperr := null;

      v_es_cambio:='N';
      --wa:19/11/2013 Verificamos si es cheque de Cambios
      begin
        select 'S'
         into v_es_cambio
          from cc_che_enviados a, lc_retenciones b
            where a.nro_cheque=clrch.nro_cheque
             and a.cod_moneda= clrch.cod_moneda
             and a.nro_cuenta = b.nro_cuenta
             and a.cod_banco= clrch.cod_bco_emisor
             AND A.LIBERADO='N'
             AND ROWNUM=1;
      exception
        when no_data_found then
          v_es_cambio:='N';
        when others then
          v_es_cambio:='N';
      end;

      --No se Valida con Cta lo que es Cambios
      if  nvl(v_es_cambio,'N')='N' then
          --Obtener datos de la Cuenta
          if clrch.tip_debito = 'C' then
             pag_cta.pr_obt_cuenta(clrch.nro_cuenta);
          end if;
      end if;
      --Verificar el registro
      prc_ver_che_rch_cam(clrch.cod_ofi_camara,clrch.cod_moneda,v_cant_error,v_cant_tot,v_procesa,clrch.registro);

      if v_procesa = 'S' then
         if g_wk_nrsecuen > 990 then
               g_hora := pag_gen.fu_obt_sig_segundo(g_hora);
               g_wk_nrsecuen := 100;
         end if;

         --L que es Cambios, no tiene accion
         if  nvl(v_es_cambio,'N')='N' then
             if clrch.tip_debito = 'C' then
                lp_actualizar_maestros;
                lp_gen_movimiento;
             else
                lp_gen_mov_contable;
             end if;
         end if;
         --Saldos de Cámara
         lp_act_camara;
         lp_act_est_cheque;

         if  nvl(v_es_cambio,'N')='N' then
           --Compensación Directa
           if clrch.com_directa = 'S' then
              lp_compensacion;
           end if;
         end if;
         --Actualizar estado del registro a Confirmado...
         update cc_che_rechazados_tmp set estado='C' where rowid = clrch.registro;
         lp_ins_cc_che_rechazados;
         lp_ins_cc_che_rechazados_det;
         p_reg_pro := p_reg_pro + 1;
      else
         p_reg_err := p_reg_err + 1;
      end if;
   end loop proceso;

   if clrch_cur%rowcount = 0 then
       Raise_application_error(-20002, 'No existen registros a ser procesados.');
   else
       p_reg_tot := clrch_cur%rowcount;
   end if;
   close clrch_cur;
   commit;

exception
  when others then
    raise_application_error(-20099, 'Error: '||replace(sqlerrm, 'ORA-',''));
end prc_pro_che_rch_cam;
/
