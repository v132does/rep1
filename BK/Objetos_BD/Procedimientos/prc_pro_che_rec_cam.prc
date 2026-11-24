CREATE OR REPLACE PROCEDURE IT.PRC_PRO_CHE_REC_CAM
   (p_cdofici in number, 
    p_cod_moneda in varchar2,
    p_reg_pro in out number,
    p_reg_err in out number,
    p_reg_tot in out number,   
    p_insertar in varchar2 default 'N',
    p_can_rec_aut in out number,
    p_mto_rec_aut in out number)
  is  
  v_fcdehoy date := pag_cal.FU_OBT_FEC_ACTUAL(4);
  v_cod_banco cc_che_recibidos.cod_bco_emisor%type := fug_obt_cod_banco;
  v_cdofcam ba_oficinas.cod_ofi_camara%type := fug_obt_ofi_camara(p_cdofici);
  -- Variables globales.
  g_modali number(3) := 41;
  g_cuenta varchar2(15) := '0';
  g_ok  varchar2(1)    := 'N';
  g_error varchar2(10000) := null;
  g_tiperr varchar2(3);
  g_oficta number(3) := to_number('0');
  g_est_che varchar2(1);
  g_cuenta_cert ge_cuentas.nro_cuenta%type;
  g_hora ge_movimientos.hora%type;
  g_wk_nrsecuen ge_movimientos.nro_secuencia%type := 0;
  -- Datos de la Cuenta
  v_cod_modalidad ge_cuentas.cod_modalidad%type;
  v_cod_oficina   ge_cuentas.cod_oficina%type;
   v_nro_cuenta    ge_cuentas.nro_cuenta%type;
  v_nro_cta_bancaria cc_cta_bancarias.nro_cuenta%type;
  v_cod_bco_receptor cc_che_recibidos.cod_bco_receptor%type; 
   v_estado        ge_cuentas.estado%type;
  v_cod_moneda    ge_cuentas.cod_moneda%type;
  v_saldo         ge_cuentas.sal_contable%type;
  v_nro_che_inicial cc_chequeras.nro_che_inicial%type;
  ---
  --Aju. automatizacion rechazo
  v_rec_aut             varchar2(1);
  v_cod_cau_rechazo     varchar2(10);
  v_des_cau_rechazo     varchar2(100);
  v_sec_rechazados      number(10):= -999;
  v_sec_rechazados_out  number(10);
  --
procedure pp_actualizar_camara
                              (p_importe in number,
                               p_cdmoned in varchar2,
                               p_tip_importe in cc_sal_camara.tip_importe%type)  is
begin
  update cc_sal_camara
     set sis_che_recibidos = nvl(sis_che_recibidos,0) + nvl(p_importe,0)
   where cod_ofi_camara = v_cdofcam
     and cod_moneda     = p_cdmoned
     and fecha          = v_fcdehoy
     and tip_importe    = p_tip_importe;

  if sql%notfound then
     insert into  cc_sal_camara
        (cod_ofi_camara,cod_moneda,fecha,sis_che_recibidos,tip_importe)
     values (v_cdofcam,p_cdmoned, v_fcdehoy,nvl(p_importe,0),p_tip_importe);
  end if;
exception
  when others then
    Raise_application_Error(-20040, 'En actualizar CC_SAL_CAMARA '||replace(sqlerrm, 'ORA-',''));
end;
PROCEDURE pp_verficar_grabacion
                                (p_bcorece  in  number,
                                 p_importe  in  number ) is

  v_existe     varchar2(1):= 'N' ;
begin
  select 'S'
    into v_existe
    from cc_che_recibidos_res
   where cod_oficina = p_cdofici
     and cod_banco   = p_bcorece
      and cod_moneda  = v_cod_moneda
      and com_directa = 'N'
     for update of cod_banco;
  If v_existe = 'S'   then
--- si el registro existe hacer update
    update cc_che_recibidos_res
       set tot_cheques =  nvl(tot_cheques,0) +  p_importe,
           can_cheques =  nvl(can_cheques,0) + 1
     where cod_oficina = p_cdofici
       and cod_moneda  = v_cod_moneda
       and cod_banco   = p_bcorece
       and com_directa = 'N';
    If sql%notfound then
      Raise_application_error(-20020, 'Al actualizar CC_CHE_RECIBIDOS_RES');
    End if;
  End if;
exception
  when no_data_found then
     insert into cc_che_recibidos_res (cod_oficina,cod_moneda,cod_banco,tot_cheques,can_cheques)
          values(p_cdofici,v_cod_moneda,p_bcorece,p_importe,1);
     If sql%notfound then
       Raise_application_error(-20021, 'Al insertar CC_CHE_RECIBIDOS_RES ');
     End if;
  when others then
     If sqlcode <= -20000 then
        raise;
     Else
       Raise_application_error(-20022, 'Error '||v_cod_moneda||'-'||p_cdofici||'-'||p_bcorece||' '||replace(sqlerrm, 'ORA-',''));
     End if;
end;

PROCEDURE pp_genera_movimiento
                              (p_BCORECE  IN  NUMBER,
                               p_IMPORTE  IN  NUMBER,
                               p_NRCHEQU  IN  NUMBER  ) IS
  vp_nro_cuenta ge_cuentas.nro_cuenta%type;

BEGIN

  If nvl(g_est_che,'x') <> 'C' then
    vp_nro_cuenta := v_nro_cuenta;
  else
    vp_nro_cuenta := g_cuenta_cert;
  End if;

  g_wk_nrsecuen:= to_number(g_wk_nrsecuen) + 1;
  if g_wk_nrsecuen > 900 then
    g_hora := pag_gen.fu_obt_sig_segundo(g_hora);
    g_wk_nrsecuen := 1;
  end if;
  
  if v_cod_moneda = 'GS' then
    insert into ge_movimientos(cod_usuario, hora ,nro_secuencia,
              cod_modulo, cod_modalidad, nro_cuenta, cod_tra_padre, cod_transaccion,
              fec_valor, fecha, nro_documento, monto, estado,
              reversado, emi_aviso, protegido, cod_mod_padre, cod_mad_padre,
              cod_banco, cod_ofi_origen, cod_oficina, cod_moneda )
     values (user ,g_hora,g_wk_nrsecuen,4,
              v_cod_modalidad,vp_nro_cuenta,320,521,v_fcdehoy,
              v_fcdehoy,p_nrchequ,p_importe,'N','N','N','N',4,
              41,p_bcorece, p_cdofici,
              v_cod_oficina, v_cod_moneda);
  else
    insert into ge_movimientos(cod_usuario, hora ,nro_secuencia, 
            cod_modulo, cod_modalidad, nro_cuenta, cod_tra_padre, cod_transaccion,
            fec_valor, fecha, nro_documento, monto, estado,
            reversado, emi_aviso, protegido, cod_mod_padre, cod_mad_padre,
            cod_banco, cod_ofi_origen, cod_oficina, cod_moneda )
    values (user ,g_hora,g_wk_nrsecuen,4,
            v_cod_modalidad,vp_nro_cuenta,320,503,v_fcdehoy,
            v_fcdehoy,p_nrchequ,p_importe,'N','N','N','N',4,
            41,p_bcorece,p_cdofici,
            v_cod_oficina, v_cod_moneda);
            
    g_wk_nrsecuen:= to_number(g_wk_nrsecuen) + 1;
    if g_wk_nrsecuen > 900 then
      g_hora := pag_gen.fu_obt_sig_segundo(g_hora);
      g_wk_nrsecuen := 1;
    end if;
   
            
    prc_obt_cta_bancaria(p_bcorece,
                         v_cod_moneda,
                         p_cdofici,
                         v_nro_cta_bancaria,
                         v_cod_bco_receptor);            
            
            
    pag_cta.PR_ACT_OPERACION (v_nro_cta_bancaria
                             ,g_hora
                             ,'C'
                             ,v_cod_moneda
                             ,p_importe
                             ,320
                             ,602
                             ,p_nrchequ
                             ,NULL
                             ,p_cdofici
                             ,4
                             ,41
                             ,null
                             ,null
                             ,null
                             ,'N'
                             ,g_wk_nrsecuen
                             ,null
                             ,null
                             ,null);         
            
    if pag_cta.fu_obt_cod_error() <> 0 then
        raise_application_error(-20010,pag_cta.fu_obt_cod_error()||  ' - '|| pag_cta.fu_obt_msj_error());
     end if;                                                           
    end if;
   
exception
  when others then
    If sqlcode <= -20000 then
       raise;
    else
       raise_application_error(-20010, 'Error en pp_gen_mov '||replace(sqlerrm, 'ORA-',''));
    End if;
END;

procedure pp_actualizar_cuenta
                              (p_oficina in out number,
                               p_cuenta  in out varchar2,
                               p_importe in     number,
                               p_cod_modalidad in out number) is
      v_nrcuent ge_cuentas.nro_cuenta%type;
begin
  If p_cod_modalidad = 41 then
    select nro_cuenta
      into v_nrcuent
      from cc_cta_corrientes
     where nro_cuenta = p_cuenta
     for update of cc_cta_corrientes.nro_cuenta;

    update cc_cta_corrientes
       set fec_ult_movimiento = v_fcdehoy,
           hor_ult_movimiento = g_hora,
           sal_total = nvl(sal_total,0) - nvl(p_importe,0)
     Where nro_cuenta = p_cuenta;
    If sql%notfound then
      Raise_application_error(-20004, 'Al actualizar CC_CTA_CORRIENTES ');
    End if;
  else
    select nro_cuenta, cod_modalidad, cod_oficina
      into v_nrcuent,  p_cod_modalidad, p_oficina
      from cc_cta_bancarias
     where nro_cuenta    = p_cuenta
     for update of cc_cta_bancarias.nro_cuenta;

    update cc_cta_bancarias
       set fec_ult_movimiento = v_fcdehoy,
           hor_ult_movimiento = g_hora,
           sal_total = nvl(sal_total,0) - nvl(p_importe,0)
      where nro_cuenta    = p_cuenta;
    If sql%notfound then
      Raise_application_error(-20005,'Al actualizar CC_CTA_BANCARIAS');
    End if;
  End if;
exception
  when no_data_found then
      Raise_application_error(-20006,'Modalidad/Oficina/Cuenta '||to_char(v_cod_modalidad,'999')||'-'||
             to_char(p_oficina,'999')||'-'||p_cuenta||' no existe!!!');
  when too_many_rows then
      Raise_application_error(-20007, 'Existen varios registros para la cuenta '||p_cuenta);
  when others then
     If sqlcode <= -20000 then
       raise;
     else
      Raise_application_error(-20008,'Error en pp_act_cuenta '||replace(sqlerrm, 'ORA-',''));
     End if;
end;

PROCEDURE pp_cheques_recibidos IS
  ok            boolean;
  v_est         varchar2(1);
  v_imp         number := 0;
  v_error       varchar2(1000);  
  -- CROCSCRC-1-CONTROL SOBREGIROS-JUANMA:  
  v_existe        varchar2(1)                           := 'N';  
  v_cabecera      long;  
  v_detalle       long;
  v_msj_inicio    varchar2(2000)                        := 'Buenas, existen cuentas que en el proceso de Clearing queda sobregirado por encima del techo establecido:';
  v_mensaje       long;
  v_conn          utl_smtp.connection;
  v_dir_de        varchar2(100)                         := fug_obt_pardinamico('CAM_MAR_DIR_MAI_NET');--'bbvanet@bbva.com.py';
  v_dir_para      ge_par_dinamicos.val_parametro%type   := FUG_OBT_PARDINAMICO('DIR_COR_CON_SOBREGIROS');
  v_asunto        varchar2(500)                         := 'Control Sobregiros';
  v_color         varchar2(100); -- sirve para sombrear linea de por medio
  v_contar        number;
  v_contar2       number;
  v_sombrear      varchar2(1);
  --
  v_lugar varchar2(500);
  cursor clrec_cur is
       select c.*, c.rowid registro
         from cc_che_recibidos c
        where nvl(cod_ofi_camara,v_cdofcam) = v_cdofcam
          and nvl(est_cheque,'N') = 'N'
          and cod_usuario = user
          and cod_moneda = p_cod_moneda
          and fec_proceso = v_fcdehoy
        order by nro_cuenta;
  --
  clrec clrec_cur%rowtype;

--
procedure lp_validar_detalle
                            ( p_nrcuent   in  varchar2,
                              p_nrcheque  in  number ,
                              p_importe   in out number ,
                              p_ok         out boolean  ) is
  -- CROCSCRC-1-CONTROL SOBREGIROS-JUANMA                                
  v_sal_linea           cc_cta_corrientes.sal_total%type;
  v_nvo_estado          cc_cta_corrientes.estado%type;
  v_sal_disponible      cc_cta_corrientes.sal_total%type;
  v_procesa             varchar2(2);
  v_sal_combinada       cc_cta_corrientes.sal_total%type;       
  v_cod_modulo          cc_cta_corrientes.cod_modulo%type;      
  v_cod_tra_padre       ge_movimientos.cod_tra_padre%type := '320';
  v_cod_mod_padre       ge_movimientos.cod_mod_padre%type := '4';
  v_cod_mad_padre       ge_movimientos.cod_mad_padre%type := '41';
  v_sal_total           number;
  v_sal_total2          number;
  g_cod_moneda          ge_movimientos.cod_moneda%type;
  v_serie               cc_chequeras.serie%type;
  v_combinada           varchar2(2) := 'NO';
PROCEDURE pp_validar_cuenta
                              ( p_nrcuent  in varchar2,
                                p_ok         out boolean  ) is
  v_tip_dev varchar2(1);
begin
  p_ok := true;
  if g_cuenta <> nvl(p_nrcuent,'a') then  -- solo si hubo cambio de cta
     pag_cta.PR_OBT_CUENTA(p_nrcuent);
      v_nro_cuenta := p_nrcuent;
      v_estado := pag_cta.g_ctas.estado;
      v_cod_oficina := pag_cta.g_ctas.cod_oficina;
      v_cod_modalidad := pag_cta.g_ctas.cod_modalidad;
     v_cod_moneda := pag_cta.g_ctas.cod_moneda;
     v_saldo := pag_cta.g_ctas.sal_disponible;
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
    --Aju. automatizacion rechazo
    if v_estado in ('C','P','T') THEN
       prc_ver_che_rec_aut(clrec.nro_cuenta, clrec.nro_cheque,v_estado, v_rec_aut,v_cod_cau_rechazo,v_des_cau_rechazo);

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
  v_est_cheque   varchar2(1);
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
                                         'P',p_importe, v_nro_che_inicial,
                                          v_error,v_cuenta);
    */
    v_est_cheque := pac_che.FU_CON_CAM_EST_CHE(p_nro_cuenta,p_nro_cheque,
                                         'P',p_importe, v_nro_che_inicial,
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
       --Aju. automatizacion rechazo
       prc_ver_che_rec_aut(clrec.nro_cuenta, clrec.nro_cheque,v_estado, v_rec_aut,v_cod_cau_rechazo,v_des_cau_rechazo);
       
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

begin
  p_ok := true;
  if nvl(p_nrcheque,0) <= 0 then
     if g_error is null then
        g_error := 'Numero de cheque incorrecto.';
     end if;
     p_ok := false;
  end if;
  pp_validar_cuenta(p_nrcuent,p_ok);
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
-- CROCSCRC-1-CONTROL SOBREGIROS-JUANMA  
  --monto linea de sobregiro:
  v_sal_linea := FUC_OBT_MTO_LIN_SOB(v_nro_cuenta);
  --monto saldo disponible:
  PAG_CTA.PR_VER_OPERACION(v_nro_cuenta,
                           v_cod_tra_padre,
                           v_cod_mod_padre,
                           v_cod_mad_padre,
                           'D',                           
                           null,
                           null,
                           v_cod_oficina,
                           v_cod_modulo,
                           v_cod_modalidad,
                           v_nvo_estado,
                           v_sal_disponible, 
                           v_procesa); 
  --preguntamos si es cuenta combinada:
     begin
       select decode(c.cta_combinada,'S','SI','N','NO')
         into v_combinada
         from (select a.cod_modulo,
                      a.cod_modalidad,
                      a.nro_cuenta,
                      a.cod_persona,
                      a.estado,
                      a.descripcion,
                      a.cod_moneda,
                      a.cta_combinada
                 from GV_QRY_AHORROS a
               union all
               select b.cod_modulo,
                      b.cod_modalidad,
                      b.nro_cuenta,
                      b.cod_persona,
                      b.estado,
                      b.descripcion,
                      b.cod_moneda,
                      b.cta_combinada
                 from GV_QRY_CTA_CTES b) c
        where c.nro_cuenta = v_nro_cuenta
          and c.cod_persona = fug_obt_cli_principal(c.nro_cuenta);
     exception
       when others then
         v_combinada := 'NO';
     end;
  --monto saldo cuenta combinada, en caso que sea combinada:  
  v_sal_combinada := PAG_CTA.G_CTAS.SAL_DIS_COMBINADA;
  v_sal_total := nvl(v_sal_linea, 0)+ nvl(v_sal_disponible, 0)+nvl(v_sal_combinada, 0)-nvl(p_importe,0);
  v_sal_total2 := v_sal_total;
  begin
    select a.cod_moneda
     into g_cod_moneda
     from ge_cuentas a
     where a.nro_cuenta = v_nro_cuenta;
  exception
    when others then
       g_cod_moneda := null;
  end;
  -- se dolariza en caso que la cuenta sea distinto de dólares:
  v_sal_total :=  nvl(pag_gen.fu_con_mon_a_moneda(g_cod_moneda,              -- moneda origen
                                                  pag_gen.fu_obt_mon_fuerte, -- moneda dolar
                                                  v_sal_total), 0);  
  if v_sal_total <= (to_number(fug_obt_pardinamico('MTO_LIM_CON_SOBREGIROS')) * -1) then    
    begin
     select a.serie
      into v_serie
      from cc_chequeras a
     where a.nro_cuenta = v_nro_cuenta
      and (p_nrcheque between a.nro_che_inicial and a.nro_che_final);
    exception
      when no_data_found then
         dbms_output.put_line('No se ha encontrado la serie del cheque '||p_nrcheque||' '||' cuenta: '||v_nro_cuenta);
      when others then
         v_serie := null;
    end;
      --armar detalle y cambiar la variable v_existe := 'S'
     v_existe   := 'S';  
     --* usamos para sombrear la linea de por medio en la grilla Html:        
     v_contar := nvl(v_contar, 0) + 1;
     v_contar2 := mod(v_contar,2);
     if v_contar2 = 0 then
        v_color := 'BGCOLOR="Beige"';
     else
        v_color := null;
     end if;
     --*
     v_detalle := v_detalle ||'<tr '||v_color||'>
                                  <td align="left">'||v_nro_cuenta||'</td>
                                  <td align="center">'||v_combinada||'</td>
                                  <td align="left">'||fue_obt_des_moneda(g_cod_moneda)||'</td>
                                  <td align="right">'||v_serie ||'</td>
                                  <td align="right">'||p_nrcheque ||'</td>
                                  <td align="right">'||to_char(p_importe,'999g999g999g999g999g999d99')||'</td>
                                  <td align="right">'||to_char(v_sal_total2,'999g999g999g999g999g999d99')||'</td>
                               </tr>';
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

begin
  g_modali := 41;
  g_cuenta := '0';
  g_ok     := 'N';
  g_error  := null;
  g_oficta := to_number('0');
  p_reg_pro := 0;
  p_reg_err := 0;
  --Aju. automatizacion rechazo
  p_can_rec_aut := 0;
  p_mto_rec_aut := 0;
  --
  select count(*)
    into p_reg_tot
    from cc_che_recibidos c
   where nvl(cod_ofi_camara,v_cdofcam) = v_cdofcam
     and nvl(est_cheque,'N') = 'N'
     and cod_usuario = user
     and cod_moneda = p_cod_moneda
     and fec_proceso = v_fcdehoy;

  if clrec_cur%isopen then
     close clrec_cur;
  end if;
  open clrec_cur;  
  /* ciclo principal */
  <<proceso>>
  loop
    fetch clrec_cur into clrec;
    exit when clrec_cur%notfound;
    g_error := null;
    g_tiperr := null;
    --Aju. automatizacion rechazo
    v_rec_aut:= 'N';
    v_cod_cau_rechazo:= null;
    v_des_cau_rechazo:= null;    
   -- :sc_mens := 'Procesando el cheque nro.: '||
   --              to_char(clrec.nro_cheque,'9999999')||' de la cuenta: '||clrec.nro_cuenta;
   -- synchronize;
    v_lugar := 'pp_validar_detalle';
    lp_validar_detalle(clrec.nro_cuenta, clrec.nro_cheque, clrec.monto,ok);

    if g_error is null then
      v_imp := nvl(v_imp,0) + nvl(clrec.monto,0);
      g_hora := to_char(sysdate,'hh24:mi:ss');
      if g_wk_nrsecuen >= 800 then
        --sig segundo
        g_hora := pag_gen.fu_obt_sig_segundo(to_char(sysdate,'hh24:mi:ss'));
        g_wk_nrsecuen := 1;
      end if;
          v_lugar := 'pp_actualizar_cuenta';
      If nvl(g_est_che,'x') <> 'C' then --Si no es cuenta certificada
        pp_actualizar_cuenta (v_cod_oficina, v_nro_cuenta,
                              clrec.monto,v_cod_modalidad);
      else --Cuenta certificada
        v_cod_modalidad := 44;
        v_lugar := 'pp_act_cuenta 44';
        pp_actualizar_cuenta (v_cod_oficina, g_cuenta_cert,
                              clrec.monto,v_cod_modalidad);
      End if;

      if v_estado = 'I' then
            v_lugar := 'set_variables';
          pag_cta.pr_set_variables(USER, v_fcdehoy,
                            320,
                            'N',--estado mvto
                            'N',--reversado
                            g_wk_nrsecuen, 
                            'N', -- estado pasa normal
                            p_cdofici,--ori origen
                            4,--mod_padre
                            41);--mad_padre
         PAG_CTA.PR_ACT_ESTADO(v_nro_cuenta,'N',v_fcdehoy,g_hora,null,'S');
          g_wk_nrsecuen:= to_number(g_wk_nrsecuen) + 1;
      end if;
          v_lugar := 'pp_genera_mov';
      pp_genera_movimiento(clrec.cod_bco_receptor,clrec.monto,clrec.nro_cheque);
      v_cod_modalidad := g_modali;
      v_nro_cuenta    := clrec.nro_cuenta;
      v_cod_oficina   := g_oficta;
          v_lugar := 'pp_verificar_grabacion';
      pp_verficar_grabacion(clrec.cod_bco_receptor,clrec.monto);
          v_lugar := 'obtener cheques';
      ---- actualizo tabla de detalle de cheques gerencia/certificado
      v_error := PAC_CHE.FU_ACT_PAG_CHE(v_nro_cuenta,
                                        clrec.nro_cheque,
                                        clrec.monto,
                                         user,
                                         v_fcdehoy,
                                         g_hora,
                                         null,--nro_caja
                                         clrec.cod_bco_receptor,
                                         320,
                                         v_cod_moneda,
                                         p_cdofici,
                                        4,
                                        g_modali);
      If v_error is not null then
        Raise_application_error(-20030, v_error);
      end if;
          v_lugar := 'ppp_act_camara';
      pp_actualizar_camara(clrec.monto,v_cod_moneda,clrec.tip_importe);
      v_est := 'S';
      p_reg_pro := p_reg_pro + 1;
      update cc_che_recibidos
         set est_cheque = 'P'
       where rowid = clrec.registro;
      If sql%notfound then
        raise_application_error(-20001, 'Al actualizar CC_CHE_RECIBIDOS-1');
      End if;
      --el monto cobrado al saldo actual
      v_saldo:=nvl(v_saldo,0)-nvl(clrec.monto,0);
    else
      -- actualizo cuenta cancelada y orden de no pagar --
        update cc_che_recibidos
           set cod_cau_devolucion  = g_tiperr,
               est_cheque = 'R'
         where rowid = clrec.registro;
        If sql%notfound then
          Raise_application_error(-20002, 'Al actualizar CC_CHE_RECIBIDOS-2');
        End if;
        
        --Aju. automatizacion rechazo
        IF nvl(v_rec_aut,'N')='S' then
          v_lugar:= 'Proc.Rec.Aut';
          v_sec_rechazados:= nvl(v_sec_rechazados,0) + 1;
          prc_aut_rch_clearing(clrec.nro_cuenta,clrec.nro_cheque,clrec.cod_moneda, clrec.fec_proceso, v_sec_rechazados,v_sec_rechazados_out);
          v_sec_rechazados:= v_sec_rechazados_out;
          p_can_rec_aut := nvl(p_can_rec_aut,0) + 1;
          p_mto_rec_aut := nvl(p_mto_rec_aut,0) + nvl(clrec.monto,0);
        else
          p_reg_err := p_reg_err + 1;
        end if; 
               
      g_error  := null;
      g_tiperr := null;
      v_est := 'N';
    end if;
  end loop proceso;

  if clrec_cur%rowcount = 0 then
     Raise_application_error(-20003, 'No existen registros a ser procesados.');
  else
     p_reg_tot := clrec_cur%rowcount;
  end if;
  close clrec_cur;  
  commit;
 -- CROCSCRC-1-CONTROL SOBREGIROS-JUANMA
  if v_existe = 'S' then
      v_cabecera := '<HTML>
                    <HEAD>
                      <META HTTP-EQUIV="CONTENT-TYPE" CONTENT="TEXT/HTML; CHARSET=ISO-8859-1">
                      <TITLE>Control de Sobregiros</TITLE>
                       <STYLE TYPE="TEXT/CSS">                        
                       </STYLE>
                    </HEAD>
                    <BODY>
                    <H1 ALIGN="LEFT"><FONT FACE="ARIAL" SIZE="2"></B>'||v_msj_inicio||'</FONT></H1>
                    <FONT FACE="ARIAL, HELVETICA, SANS-SERIF" SIZE="2">
                    <TABLE WIDTH="100%" BORDER="1" ALIGN="CENTER">  
                    <tr>    
                     <TH  BGCOLOR="CornflowerBlue" HEIGHT="5"><FONT COLOR="WHITE">CUENTA</FONT></TH>
                     <TH  BGCOLOR="CornflowerBlue" HEIGHT="5"><FONT COLOR="WHITE">CTA_COMBINADA</FONT></TH>
                     <TH  BGCOLOR="CornflowerBlue" HEIGHT="5"><FONT COLOR="WHITE">MONEDA</FONT></TH>
                     <TH  BGCOLOR="CornflowerBlue" HEIGHT="5"><FONT COLOR="WHITE">SERIE</FONT></TH>
                     <TH  BGCOLOR="CornflowerBlue" HEIGHT="5"><FONT COLOR="WHITE">CHEQUE</FONT></TH>
                     <TH  BGCOLOR="CornflowerBlue" HEIGHT="5"><FONT COLOR="WHITE">MONTO DEL CHEQUE</FONT></TH>
                     <TH  BGCOLOR="CornflowerBlue" HEIGHT="5"><FONT COLOR="WHITE">SALDO FINAL DE LA CUENTA</FONT></TH>
                    </tr>';
      v_mensaje := v_cabecera||v_detalle||'</TABLE>
                                             </BODY>
                                               </HTML>';
     
      --enviar correo:
      v_conn := it_mail.begin_mail(v_dir_de,
                                   v_dir_para,
                                   v_asunto,
                                   it_mail.multipart_mime_type);
      it_mail.attach_text(v_conn,v_mensaje,'text/html');    
      it_mail.end_mail(v_conn);
  end if;
  /*
  if nvl(p_reg_err,0) > 0 then
     pp_mensaje('El proceso ha finalizado con errores !!. ' );
     :sc_mens := 'El proceso ha finalizado con errores !!.';
     synchronize;
  end if;
  */
exception
  when others then
    If sqlcode <= -20000 then
       raise;
    Else
       Raise_application_error(-20097, 'Error en '||v_lugar||' '||SQLERRM);
    End if;
END;
begin
  IF P_INSERTAR = 'I' THEN
    begin
      insert into cc_che_recibidos
          (fec_proceso,nro_cheque,nro_cuenta,monto,cod_bco_emisor,cod_bco_receptor, cod_cau_devolucion,
           cod_ofi_camara,est_cheque,alerta_uv,datamatrix,tip_importe,banda_cmc7,cod_moneda)
          (select fec_proceso,nro_cheque,nro_cuenta,monto, v_cod_banco,cod_bco_receptor,null,
           nvl(cod_ofi_camara,v_cdofcam),null,alerta_uv,datamatrix,tip_importe,banda_cmc7,cod_moneda
             from cc_che_recibidos_tmp
             where cod_usuario = substr(upper(user),1,10)
               and cod_moneda = p_cod_moneda
               and nvl(fec_proceso,v_fcdehoy) = v_fcdehoy
              and nvl(cod_ofi_camara,v_cdofcam) = v_cdofcam);
      delete from cc_che_recibidos_tmp
       where cod_usuario = substr(upper(user),1,10);
    exception
    when others then
        If sqlcode <= -20000 then
           raise;
        Else
           Raise_application_error(-20097, 'Error al insertar'||replace(sqlerrm, 'ORA-',''));
        End if;
     END;
  END IF;
  pp_cheques_recibidos;
  --Realizar el proceso de Cobertura de Sobregiros entre Cuentas Combinadas cuando se procesa Ofic. 31, Agregado el 16/02/2010
  if v_cdofcam =  fug_obt_ofi_matriz then
     prc_tra_cta_com_sob;
  end if;
  
Exception
  When OTHERS then
    If sqlcode <= -20000 then
       raise;
    Else
       Raise_application_error(-20098, 'Error '||replace(sqlerrm, 'ORA-',''));
    End if;
end prc_pro_che_rec_cam;
/
