CREATE OR REPLACE PROCEDURE IT.PRC_VER_CHE_REC_CAM (p_cod_oficina in number,
                                                 p_reg_pro in out number,
                                                 p_reg_err in out number,
                                                 p_reg_tot in out number,
                                                 p_sum_monto in out number,
                                                 p_procesar in out varchar2,
                                                 p_cod_moneda in varchar2 DEFAULT NULL,  -- 21/08/2013 PN DI: validación de moneda en base al archivo que se esta importando
                                                 p_can_rec_aut in out number,
                                                 p_mto_rec_aut in out number) is
  ok            boolean;
  v_est         varchar2(1);
  v_error       varchar2(1000);
  v_fcdehoy     date := pag_cal.fu_obt_fec_actual(4);
  v_cdofcam     number(3) := FUG_OBT_OFI_CAMARA(p_cod_oficina);
  -- Datos de la Cuenta
  v_cod_modalidad ge_cuentas.cod_modalidad%type;
  v_cod_oficina   ge_cuentas.cod_oficina%type;
   v_nro_cuenta    ge_cuentas.nro_cuenta%type;
   v_estado        ge_cuentas.estado%type;
  v_cod_moneda    ge_cuentas.cod_moneda%type;
  v_saldo         ge_cuentas.sal_contable%type;
  v_nro_che_inicial cc_chequeras.nro_che_inicial%type;
  v_cant_repe     number(9);
  -- Datos Globales
--   p_procesar varchar2(1) := 'S';
  g_modali number(3) := 41;
  g_cuenta varchar2(15) := '0';
  g_ok  varchar2(1)    := 'N';
  g_error varchar2(10000) := null;
  g_tiperr varchar2(3);
  g_oficta number(3) := to_number('0');
  g_est_che varchar2(1);
  g_cuenta_cert ge_cuentas.nro_cuenta%type;
  ---automatizacion rechazo
  v_rec_aut         varchar2(1);
  v_cod_cau_rechazo varchar2(10);
  v_des_cau_rechazo varchar2(100);
  v_can_reg         number(10);
  v_ya_existe       number(10);
  v_nro_lote        number(10);
  rp_rch_aut        cc_che_rec_automaticos%ROWTYPE;

  -- Cursor principal de cheques a Verificar
  cursor clrec_cur is
     select c.*, c.rowid registro
       from cc_che_recibidos_tmp c
      where nvl(cod_ofi_camara, v_cdofcam) = v_cdofcam
        and nvl(est_cheque, 'N') = 'N'
        and cod_usuario = user
        and cod_moneda = p_cod_moneda
        and nvl(fec_proceso, v_fcdehoy) = v_fcdehoy
      order by nro_linea, nro_cuenta;
  --
  clrec clrec_cur%rowtype;

--- Procedimiento para validar.
procedure lp_validar_detalle
                            ( p_nrcuent   in  varchar2,
                              p_nrcheque  in  number ,
                              p_importe   in out number ,
                              p_banco     in number,
                              p_ok         out boolean  ) is
PROCEDURE pp_validar_cuenta
                              ( p_nrcuent  in varchar2,
                                p_ok         out boolean  ) is
  v_tip_dev varchar2(1);
begin
  p_ok := true;
  if g_cuenta <> nvl(p_nrcuent,'a') then  -- solo si hubo cambio de cta
     pag_cta.PR_OBT_CUENTA(p_nrcuent);
     --cuentas corrientes
     v_nro_cuenta := p_nrcuent;
     v_estado := pag_cta.g_ctas.estado;
     v_cod_oficina := pag_cta.g_ctas.cod_oficina;
     v_cod_modalidad := pag_cta.g_ctas.cod_modalidad;
     v_cod_moneda := pag_cta.g_ctas.cod_moneda;
     v_saldo := pag_cta.g_ctas.sal_disponible;

     if pag_cta.g_cod_error = '12' then --Cuenta Inexistente
       v_nro_cuenta := null;
       v_estado := null;
       v_cod_oficina := null;
       v_cod_modalidad := null;
       v_cod_moneda := null;
       v_saldo := null;
       p_ok := false; --No debe permitir procesar en estos casos, Agregado en Fecha 25/02/2010
     end if;
    
        
     
 end if;
 
 
 -- 21/08/2013 DI PN: Validación de que coincida la moneda del cheque con la moneda del formato de archivo que se esta importando
 
 if v_cod_moneda <> p_cod_moneda then
   g_error := 'No corresponde la Moneda con el Formato del Archivo.';
   p_ok := false;
 end if;

 if v_estado in ('C','T','D','P') or
    v_estado is null then
    --p_ok := false;
    if v_estado = 'C' then
       g_error := 'Cuenta Cancelada';
       v_tip_dev := 'C';
    elsif v_estado in ('T','D') then
       g_error := 'Cuenta Bloqueada';
       v_tip_dev := 'B';
    elsif v_estado = 'P' then
       g_error := 'Cuenta Cerrada';
       v_tip_dev := 'C';
    elsif v_estado is null then
       g_error := 'Cuenta no existe o con estado incorrecto';
       v_tip_dev := null;
    end if;
    If v_tip_dev is not null then
       begin
         g_tiperr := fug_obt_cau_devolucion('D', v_tip_dev);
      exception
        when no_data_found then null;
      end;
    End if;
    --automatizacion rechazo
    if v_estado in ('C','P','T','D') THEN
       PRC_VER_CHE_REC_AUT(clrec.nro_cuenta, clrec.nro_cheque,v_estado, v_rec_aut,v_cod_cau_rechazo,v_des_cau_rechazo);
       
       --Si la cta esta bloqueada verifica si el/los firmantes se encuentran inhbidos 
       if v_estado in ('T') then
          if fuc_ver_inh_che_devueltos(clrec.nro_cuenta) = 'S' then
            v_rec_aut := 'S';
          else --no cumple condicion de personas inhibidas
            v_rec_aut := 'N';
          end if;
       end if;       
       
       if v_rec_aut='S' then
          g_tiperr:= v_cod_cau_rechazo;
       end if;
    end if;    
 end if;
exception
    when no_data_found then
      g_error := 'Cuenta no existe';
      v_cod_modalidad := null;
      p_ok := false;
   when others then
      if g_error is null then
         g_error := 'Al buscar cuenta.';
      end if;
      p_ok := false;
end pp_validar_cuenta;
PROCEDURE pp_verifica_estado_cheque
                                  (p_nro_cuenta  in varchar2,
                                   p_cod_oficina in number,
                                   p_nro_cheque  in number,
                                   p_importe     in out number,
                                   p_ok          in out boolean) IS
  v_error       varchar2(2000);
  v_cuenta      varchar2(15);
  v_est_cheque  varchar2(1);
  v_desc_estado varchar2(100);
BEGIN
  g_est_che := PAC_CHE.FU_OBT_EST_CHE(p_nro_cuenta,p_nro_cheque,v_error);
  --Verifica si existe el cheque de lo contrario da un mensaj.
  If v_error is not null then
    If g_ERROR is not null then
      g_ERROR := g_ERROR||' - '||v_error;
    else
      g_ERROR := v_error;
    End if;
    p_ok := false;
  end if;
  If g_est_che = 'E' then
    --verifica si es cheque gerencia
    v_error := null;
    /*
    v_error := pac_che.FU_CON_CAM_EST_CHE(p_nro_cuenta,p_nro_cheque,
                                         'P',p_importe,v_nro_che_inicial,
                                          v_error,v_cuenta);
    */
    v_est_cheque := pac_che.FU_CON_CAM_EST_CHE(p_nro_cuenta,p_nro_cheque,
                                         'P',p_importe,v_nro_che_inicial,
                                          v_error,v_cuenta);
    If v_error is not null and rtrim(v_error) <> 'E' then
      If g_ERROR is not null then
        g_ERROR := g_ERROR||' - '||v_error;
      else
        g_ERROR := v_error;
      End if;
      p_ok := false;
    end if;
  End if;
  If g_est_che = 'C' then
    --verifica si es cheque certificado
    v_error := null;
    v_est_cheque := pac_che.FU_CON_CAM_EST_CHE(p_nro_cuenta,p_nro_cheque,
                                         'P',p_importe,v_nro_che_inicial,
                                          v_error,g_cuenta_cert);
    If v_error is not null and rtrim(v_error) <> 'C' then
      g_ERROR := g_ERROR||' - '||v_error;
      p_ok := false;
    end if;
  elsif g_est_che = 'G' then
    --- Verificar importe en tabla de detalle de cheque gerencia
    v_error := null;
    v_est_cheque := pac_che.FU_CON_CAM_EST_CHE(p_nro_cuenta,p_nro_cheque,
                                         'P',p_importe,v_nro_che_inicial,
                                          v_error,v_cuenta);
    If v_error is not null and rtrim(v_error) <> 'G' then
      g_ERROR := g_ERROR||' - '||v_error;
      p_ok := false;
    end if;
  elsif g_est_che not in ('E','G') then
     --Obtener la descripcion del estado del cheque
     begin
        v_desc_estado := FUE_OBT_DES_REFCODES ('EST_CHEQUE',  ltrim(rtrim(g_est_che)));
        if v_desc_estado = 'Referencia  no registrada en el Sistema' then
           v_desc_estado := null;
        End if;
     exception
        when others then null ;
     End;
     g_ERROR := g_ERROR||' - '||'Cheque en estado '||g_est_che
                      ||'('||v_desc_estado||')';

     If g_est_che = 'O' then
      ---automatizacion rechazo
      IF v_rec_aut='N' THEN
         begin
               g_tiperr := fug_obt_cau_devolucion('D', 'O');
           exception
              when no_data_found then
               null;
           end;

            begin
             select g_error||'-'||descripcion
               into g_error
               from ge_causales
              where ge_causales.cod_causa = (select cod_causa
                                                from cc_che_ord_no_pagos
                                               where nro_cheque = p_nro_cheque);
           exception
              when others then null;
           end;
       END IF;
       --automatizacion rechazo
       PRC_VER_CHE_REC_AUT(clrec.nro_cuenta, clrec.nro_cheque,v_estado, v_rec_aut,v_cod_cau_rechazo,v_des_cau_rechazo);
       
       --Si la cta esta bloqueada verifica si el/los firmantes se encuentran inhbidos 
       if v_estado in ('T') then
          if fuc_ver_inh_che_devueltos(clrec.nro_cuenta) = 'S' then
            v_rec_aut := 'S';
          else --no cumple condicion de personas inhibidas
            v_rec_aut := 'N';
          end if;
       end if;
       
       if v_rec_aut='S' then
          g_tiperr:= v_cod_cau_rechazo;
       end if;
     else
       p_ok := false;
     End if;
  End if;
exception
  when others then
    raise_application_error(-20004, 'Error en pp_ver_est_che '||replace(sqlerrm, 'ORA-',''));
END;

procedure pp_ver_bco_receptor(p_banco in number,
                              p_ok    in out boolean) is
   v_existe varchar2(1);
begin

   begin
     select 'S'
       into v_existe
       from ge_bancos b
      where b.cod_banco = p_banco
        and b.estado = 'A'
        and b.ubicacion = 'L';
   exception
      when others then
        if g_error is null then
           g_error := 'Código de Banco no válido.';
        else
           g_error := g_error||'/Código de Banco no válido.';
        end if;
        p_ok := false;
   end;
end pp_ver_bco_receptor;

--Agregado para validar si la cuenta tiene firmantes inhibidos, 01/01/2010
procedure pp_ver_fir_cuenta(p_nro_cuenta  in varchar2,
                            p_ok    in out boolean) is
   v_inhibido varchar2(1) := 'N';   
begin

  select fuc_obt_fir_exc_inh(p_nro_cuenta)
    into v_inhibido
    from dual;

  if v_inhibido = 'S' then
    if g_error is null then
       g_error := 'Advertencia: Cuenta con firmante Inhabilitado - Ley de Cheques.';
    else
       g_error := g_error||'/Advertencia: Cuenta con firmante Inhabilitado - Ley de Cheques.';
    end if;
  end if;
end pp_ver_fir_cuenta;

begin
  p_ok := true;
  if nvl(p_nrcheque,0) <= 0 then
     if g_error is null then
        g_error := 'Numero de cheque incorrecto.';
     end if;
     p_ok := false;
  end if;
  pp_validar_cuenta(p_nrcuent,p_ok);
  pp_ver_bco_receptor(p_banco,p_ok);
  pp_ver_fir_cuenta(p_nrcuent,p_ok); --Verifica Firmantes Inhabilitados, 01/02/2010
  if p_ok then
     g_ok := 'S';
  else
     g_ok := 'N';
  end if;
  g_cuenta := p_nrcuent;
  g_oficta := v_cod_oficina;
  g_modali := v_cod_modalidad;
  p_ok := true;
  --Solo debe verificar el cheque si existe la cuenta
  If v_cod_modalidad is not null then
     pp_verifica_estado_cheque(v_nro_cuenta, v_cod_oficina,
                            p_nrcheque,p_importe, p_ok);
  End if;
  if g_ok = 'N' then -- si la cuenta tuvo problemas
      p_ok := false;
  end if;
  if nvl(p_importe,0) <= 0 then
    if g_error is null then
       g_error := 'Importe incorrecto.';
    else
       g_error := g_error||'/importe incorrecto';
    end if;
    p_ok := false;
  end if;
  /* RAMG: ya no se controla desde el 07/ago/06 a pedido del BR
  if :recibidos.sc_estado = 'S' then -- tiene bloqueo de saldo
     if nvl(:recibidos.sc_saldo,0) < nvl(p_importe,0) then
        --p_ok := false;
        --g_ok := 'N';
        if g_error is null then
           g_error := 'Cuenta con saldo bloqueado';
        else
           g_error := g_error||'-'||
           'Cuenta con saldo bloqueado';
        end if;
     end if;
  end if;
  */
end;

--
begin
  p_reg_pro := 0;
  p_reg_err := 0;
  p_reg_tot := 0;
  p_can_rec_aut := 0;
  p_mto_rec_aut := 0;  

  -- Suma y total de cheques a procesar
  select count(*),sum(monto)
    into p_reg_tot, p_sum_monto
    from cc_che_recibidos_tmp c
   where nvl(fec_proceso,v_fcdehoy) = v_fcdehoy
     and nvl(cod_ofi_camara,v_cdofcam) = v_cdofcam
     and cod_usuario = user
     and cod_moneda = p_cod_moneda
     and nvl(est_cheque,'N') = 'N';

  --Verificar si existen cheques duplicados
    Begin
       select count(*)
         into v_cant_repe from
          (select fec_proceso, cod_ofi_camara, nro_cheque, nro_cuenta, cod_usuario
             from cc_che_recibidos_tmp
            where nvl(fec_proceso, v_fcdehoy) = v_fcdehoy
              and nvl(cod_ofi_camara, v_cdofcam) = v_cdofcam
              and cod_usuario = user
              and cod_moneda = p_cod_moneda
              and nvl(est_cheque, 'N') = 'N'
            group by fec_proceso, cod_ofi_camara, nro_cheque, nro_cuenta, cod_usuario
           having count(*) > 1);
    exception
      when no_data_found then
            v_cant_repe := 0;
    end;

     if v_cant_repe > 0 then
       --Mensaje de error para identificar el problema
       g_error := ' - Nro.de Cheque Duplicado - Linea: ';
       -- Si existe cheques repetidos ingresa en la tabla de errores
       insert into cc_che_rec_errores e
         (nro_cuenta, nro_cheque, msj_error, importe, cod_banco)
         select t.nro_cuenta,
                t.nro_cheque,
                g_error||to_char(t.nro_linea),
                t.monto,
                t.cod_bco_receptor
           from cc_che_recibidos_tmp t
          where nvl(fec_proceso, v_fcdehoy) = v_fcdehoy
            and nvl(cod_ofi_camara, v_cdofcam) = v_cdofcam
            and t.cod_usuario = user
            and t.cod_moneda = p_cod_moneda
            and nvl(est_cheque, 'N') = 'N'
            and exists( select 0
                         from cc_che_recibidos_tmp r
                        where nvl(r.fec_proceso, v_fcdehoy) = v_fcdehoy
                          and nvl(r.cod_ofi_camara, v_cdofcam) = v_cdofcam
                          and r.cod_usuario = user
                          and r.cod_moneda = p_cod_moneda
                          and nvl(r.est_cheque, 'N') = 'N'
                          and r.nro_cuenta = t.nro_cuenta
                          and r.nro_cheque = t.nro_cheque
                        group by fec_proceso, cod_ofi_camara, nro_cheque, nro_cuenta, cod_usuario
                       having count(*) > 1);

       -- No procesa si existen registros duplicados
       p_procesar := 'N';
       p_reg_err := p_reg_err + nvl(v_cant_repe,0);
     end if;

    --Verificar si existen cheques duplicados
    --automatizacion rechazo
    if nvl(fug_obt_pardinamico('CC_ACT_REC_AUT'),'N') = 'S' then
      v_cant_repe:=0;
      Begin
         select count(*)
           into v_cant_repe from
            (select a.fec_proceso, a.cod_ofi_camara, a.nro_cheque, a.nro_cuenta
               from cc_che_rec_automaticos a,cc_che_recibidos_tmp b 
              where nvl(a.fec_proceso, v_fcdehoy) = v_fcdehoy
                and nvl(a.cod_ofi_camara, v_cdofcam) = v_cdofcam
                and a.cod_moneda = p_cod_moneda
                --
                and a.fec_proceso= b.fec_proceso
                and a.cod_moneda=b.cod_moneda
                and a.nro_cheque=b.nro_cheque
                and a.nro_cuenta=b.nro_cuenta
          --
          and nvl(a.procesado,'N')='S'
              group by a.fec_proceso, a.cod_ofi_camara, a.nro_cheque, a.nro_cuenta
             );
      exception
        when no_data_found then
              v_cant_repe := 0;
      end;

      if nvl(v_cant_repe,0) > 0 then
       --Mensaje de error para identificar el problema
       g_error := ' - Nro.de Cheque Duplicado - Linea: ';
       -- Si existe cheques repetidos ingresa en la tabla de errores
       insert into cc_che_rec_errores e
         (nro_cuenta, nro_cheque, msj_error, importe, cod_banco)
         select t.nro_cuenta,
                t.nro_cheque,
                g_error||to_char(t.nro_linea),
                t.monto,
                t.cod_bco_receptor
           from cc_che_recibidos_tmp t,cc_che_rec_automaticos b 
          where nvl(T.fec_proceso, v_fcdehoy) = v_fcdehoy
            and nvl(T.cod_ofi_camara, v_cdofcam) = v_cdofcam
            and t.cod_usuario = user
            --
            and T.fec_proceso= b.fec_proceso
            and T.cod_moneda=b.cod_moneda
            and T.nro_cheque=b.nro_cheque
            and T.nro_cuenta=b.nro_cuenta;

       -- No procesa si existen registros duplicados
       p_procesar := 'N';
       p_reg_err := p_reg_err + nvl(v_cant_repe,0);
      end if;
      
      
    end if;

     --automatizacion rechazo
     --Para obtener el ultimo numero de lote y sumarle 1
     if nvl(fug_obt_pardinamico('CC_ACT_REC_AUT'),'N') = 'S' then
        begin
         select nvl(max(a.nro_lote),0)
             into v_nro_lote
              from cc_che_rec_automaticos a;
        exception
          when others then
            v_nro_lote:=0;
        end;
        v_nro_lote:= nvl(v_nro_lote,0) + 1;
     end if;     

  if clrec_cur%isopen then
     close clrec_cur;
  end if;
  open clrec_cur;

  /* ciclo de Verificacion principal */
  <<proceso>>
  loop
    fetch clrec_cur into clrec;
    exit when clrec_cur%notfound;
    g_error := null;
    g_tiperr := null;
    --automatizacion rechazo
    v_rec_aut:= 'N';
    v_cod_cau_rechazo:= null;
    v_des_cau_rechazo:= null;
        
--    v_mens := 'Verificando el cheque nro.: '||
--               to_char(clrec.nro_cheque,'9999999')||' de la cuenta: '||clrec.nro_cuenta||
--                 ' - Linea : '||to_char(clrec.nro_linea) ;

    lp_validar_detalle(clrec.nro_cuenta,clrec.nro_cheque,clrec.monto,clrec.cod_bco_receptor,ok);
    --Para ver si se va a ejecutar el procesamiento
    If ok = false then
      p_procesar := 'N';
    End if;
    if g_error is not null then   
      g_error := g_error||'- Linea: '||clrec.nro_linea;
      --automatizacion rechazo - No se debe insertar en errores
      IF nvl(v_rec_aut,'N') ='N' THEN
        insert into CC_CHE_REC_ERRORES(nro_cuenta,nro_cheque,msj_error,importe,cod_banco, Cod_Moneda)
            values (clrec.nro_cuenta, clrec.nro_cheque,substr(g_error,1,100),
                    clrec.monto, clrec.cod_bco_receptor,p_cod_moneda);
        
        p_reg_err := p_reg_err + 1; 
      ELSE
        --inserta rechazos automaticos
        rp_rch_aut.nro_cheque         := clrec.nro_cheque;
        rp_rch_aut.fec_proceso        := clrec.fec_proceso;
        rp_rch_aut.nro_cuenta         := clrec.nro_cuenta; 
        rp_rch_aut.monto              := clrec.monto; 
        rp_rch_aut.cod_bco_receptor   := clrec.cod_bco_receptor; 
        rp_rch_aut.cod_ofi_camara     := clrec.cod_ofi_camara;
        rp_rch_aut.cod_oficina        := v_cod_oficina;
        rp_rch_aut.cod_cau_devolucion := v_cod_cau_rechazo; 
        rp_rch_aut.des_cau_devolucion := v_des_cau_rechazo; 
        rp_rch_aut.cod_usuario        := clrec.cod_usuario; 
        rp_rch_aut.tip_importe        := clrec.tip_importe; 
        rp_rch_aut.cod_moneda         := clrec.cod_moneda;
        rp_rch_aut.des_error          := g_error;
        rp_rch_aut.nro_lote           := v_nro_lote;
        rp_rch_aut.origen             := 'L';
        
        prc_ins_aut_rch_clearing(rp_rch_aut);
                                 
        p_can_rec_aut := nvl(p_can_rec_aut,0) + 1;
        p_mto_rec_aut := nvl(p_mto_rec_aut,0) + nvl(clrec.monto,0);
      END IF;
      -- actualizo cuenta cancelada y orden de no pagar --
      if g_error is not null and
         g_tiperr is not null then
        update cc_che_recibidos_tmp
           set cod_cau_devolucion  = g_tiperr
         where rowid = clrec.registro;
        If sql%notfound then
          raise_application_error(-20001, 'Al actualizar CC_CHE_RECIBIDOS_TMP');
        End if;
      end if;
      g_error  := null;
      g_tiperr := null;
      v_est := 'N';
      --p_reg_err := p_reg_err + 1;
    end if;

  end loop proceso;

  if clrec_cur%rowcount = 0 then
     Raise_application_error(-20002, 'No existen registros a ser procesados.');
  else
     p_reg_tot := clrec_cur%rowcount;
  end if;
  close clrec_cur;
  commit;
/*
  if nvl(p_reg_err,0) > 0 then
     If nvl(p_procesar,'X') = 'N' then
       pp_mensaje('El proceso de verificación ha finalizado con errores !!.  Favor verifique los errores emitiendo  la  Planilla de Errores de Clearing y una vez corregidos, vuelva a ejecutar este Proceso.' );
       v_mens := 'El proceso de verificacion ha finalizado con errores !!.';
       synchronize;
     End if;
  end if;
  */
exception
  when others then
    raise_application_error(-20099, 'Error: '||replace(sqlerrm, 'ORA-',''));
end prc_ver_che_rec_cam;
/
