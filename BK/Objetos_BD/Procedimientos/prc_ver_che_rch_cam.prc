CREATE OR REPLACE PROCEDURE IT.PRC_VER_CHE_RCH_CAM(p_cod_oficina in number,
                                                p_cod_moneda in varchar2,
                                                p_reg_err in out number,
                                                p_reg_tot in out number,
                                                p_procesar in out varchar2,
                                                p_rowid in rowid default null) is                                                   
  ok              boolean;
  v_fcdehoy       date := pag_cal.fu_obt_fec_actual(4);
  v_cdofcam       number(3) := fug_obt_ofi_camara(p_cod_oficina);
  
  --Datos de la cuenta
  v_cod_modalidad ge_cuentas.cod_modalidad%type;
  v_cod_oficina   ge_cuentas.cod_oficina%type;
   v_nro_cuenta    ge_cuentas.nro_cuenta%type;
   v_estado        ge_cuentas.estado%type;
  v_cod_moneda    ge_cuentas.cod_moneda%type;
  v_saldo         ge_cuentas.sal_contable%type;
  v_est_registro  varchar2(1);
  
  g_error  varchar2(10000) := null;
  g_tiperr varchar2(3);
  v_es_cambio varchar2(1):='N';
  
  -- Cursor Principal de Cheques Rechazados a Verificar
  cursor clrch_cur is
     select c.*, c.rowid registro
       from cc_che_rechazados_tmp c
      where nvl(cod_ofi_camara, v_cdofcam) = v_cdofcam
        and nvl(estado, 'P') != 'C'
        and fec_proceso = v_fcdehoy
        and c.cod_moneda = nvl(p_cod_moneda, pag_gen.fu_obt_mon_local)
        and rowid = nvl(p_rowid,rowid) --Para verificar solo un registro
      order by nro_linea, nro_cuenta;
  --
  
  clrch clrch_cur%rowtype;
  
  
  --Validar Banco Emisor
  procedure lp_validar_banco(p_bco_emisor in number,
                             p_ok in out boolean) is
     v_existe varchar2(1);
     v_error varchar2(100);
     
  begin

     begin      
       select 'S'  
         into v_existe
         from  ge_bancos x
        where x.cod_banco = p_bco_emisor;
      exception 
        when no_data_found then
           v_existe := 'N' ;
      end;
      
      if v_existe = 'N' then
         p_ok := false;
         v_error := 'Banco Emisor no Registrado en el Sistema';
      end if;
      
      if g_error is null then
         g_error := v_error;
      else
         g_error := g_error||'/'||v_error;
      end if;    
  end lp_validar_banco;
  
  --Verificar si hay cheques repetidos
  procedure lp_validar_repetidos(p_bco_emisor in number,
                                 p_cta_libradora in varchar2,
                                 p_nro_cheque in number,
                                 p_cod_moneda in varchar2,
                                 p_ok in out boolean) is
     v_cant number(9);
     v_error varchar2(100);  
  begin
  
     begin  
       select count(1)
         into v_cant
         from cc_che_rechazados_tmp r
        where nvl(r.fec_proceso, v_fcdehoy) = v_fcdehoy
          and nvl(r.cod_ofi_camara, v_cdofcam) = v_cdofcam
          and nvl(r.estado, 'P') != 'C'
          and r.cod_bco_emisor = p_bco_emisor
          and r.nro_cheque = p_nro_cheque
          and r.cta_libradora = p_cta_libradora
          and r.cod_moneda = p_cod_moneda
        group by fec_proceso, cod_bco_emisor, cta_libradora, nro_cheque, cod_usuario;
      exception
        when no_data_found then
           v_cant := 0;
      end;    
      
      if nvl(v_cant,0) > 1 then
        v_error := 'Nro. de cheque repetido';
        p_ok := false;
      end if;  
     
      if v_error is not null then
        if g_error is null then
           g_error := v_error;
        else
           g_error := g_error||'/'||v_error;
        end if;
      end if;       
  
  end lp_validar_repetidos;            

--Valida estado de la cuenta
procedure lp_validar_cuenta(p_ok in out boolean) is
   v_error varchar2(100);   
begin
   
   v_error := null;
   
    v_nro_cuenta := pag_cta.g_ctas.nro_cuenta;
    v_estado := pag_cta.g_ctas.estado;
    v_cod_oficina := pag_cta.g_ctas.cod_oficina;
    v_cod_modalidad := pag_cta.g_ctas.cod_modalidad;
   v_cod_moneda := pag_cta.g_ctas.cod_moneda;
   v_saldo := pag_cta.g_ctas.sal_disponible;

   if v_estado in ('C','T','D','P') or
      v_estado is null then
      p_ok := false;
      if v_estado = 'C' then
         v_error := 'Cuenta Cancelada';
      elsif v_estado in ('T','D') then
         v_error := 'Cuenta Bloqueada';
      elsif v_estado = 'P' then
         v_error := 'Cuenta Cerrada';
      elsif v_estado is null then
         v_error := 'Cuenta no existe o con estado incorrecto';
      end if;
      
      if v_error is not null then
        if g_error is null then
           g_error := v_error;
        else
           g_error := g_error||'/'||v_error;
         end if;
       end if; 
   end if;
   
   --Validar Moneda
   if v_cod_moneda != clrch.cod_moneda then
      v_error := 'Moneda de la Cuenta no coincide con la Moneda del Cheque.';
      p_ok := false;
      if v_error is not null then
        if g_error is null then
           g_error := v_error;
        else
           g_error := g_error||'/'||v_error;
         end if;
       end if; 
   end if;
   
exception
    when no_data_found then
      g_error := 'Cuenta no existe';
      v_cod_modalidad := null;
      p_ok := false;
   when others then
      g_error := 'Al buscar cuenta.';
      p_ok := false;
end lp_validar_cuenta;

--Valida Cuenta Contable
procedure lp_validar_cuenta_contable(p_ok in out boolean) is
   v_error varchar2(100);
   v_tpasien ge_tip_asientos.cod_tip_asiento%type;
   v_existe varchar2(1);
begin
   
   v_error := null;
   
   --Validar si existe Cta. Contable
   begin
      select 'S' 
      into v_existe
       from cb_rubros cbr,cb_rub_oficinas cbo
      where cbo.cod_oficina = clrch.cod_oficina
        and cbo.cod_rubro   = clrch.cod_rubro
        and cbr.cod_rubro   = cbo.cod_rubro
        and cbr.imputable   = 'S'
        and cbr.cod_moneda  = clrch.cod_moneda;      
   exception
       when no_data_found then
        v_error := 'Cuenta no habilitada para la oficina'; 
   end;
   
   --Validar Tipo de Asiento
   begin
   
      select cod_tip_asiento
        into v_tpasien
        from ge_transacciones
       where cod_modulo      =  4 
         and cod_modalidad   =  41
         and cod_transaccion = 522;
   
        select 'S'
          into v_existe
          from ge_tip_asientos
         where cod_tip_asiento  = v_tpasien
           and cod_moneda       = clrch.cod_moneda
           and nvl(cod_sec_contable,'N') = 'N'
           and ind_deudor       = 'N'
           and ind_residente    in ('S','X')
           and tip_movimiento   = 'C';
   
   exception
     when no_data_found then            
        v_error := 'Tipo de Asiento no definido para la transaccion 522';   
   end;   
      
   if v_error is not null then
      p_ok := false;
      if g_error is null then
        g_error := v_error;
      else
        g_error := g_error||'/'||v_error;
      end if;
    end if; 
   
exception
   when others then
      g_error := 'Al buscar Cuenta Contable';
      p_ok := false;
end lp_validar_cuenta_contable;  

--Valida el Motivo Seleccionado
procedure lp_validar_motivo(p_ok in out boolean) is
   v_existe varchar2(1);
   v_error varchar2(100);
begin
   
   begin
      select 'S'
        into v_existe
        from ge_causales gcaus
       where gcaus.tipo = 'D'
         and gcaus.cod_causa = clrch.cod_cau_devolucion;
   exception
     when no_data_found then
        v_existe := 'N';
   end;
   
   if v_existe = 'N' then
      p_ok := false;
      v_error := 'No se encuentra Causal de Devolución';
   end if;
   
    --Cargar mensaje de error
    if v_error is not null then
      if g_error is null then
         g_error := v_error;
      else
         g_error := g_error||'/'||v_error;
      end if;
    end if;
   
end lp_validar_motivo;

--Validar Moneda
procedure lp_validar_moneda(p_ok in out boolean) is 
   v_error varchar2(100);       
begin
   
   if clrch.cod_moneda != pag_gen.fu_obt_mon_local then
      p_ok := false;
      v_error := 'Código de Moneda Incorrecto. Debe ser Moneda Local.';
   end if;
   
    --Cargar mensaje de error
    if v_error is not null then
      if g_error is null then
         g_error := v_error;
      else
         g_error := g_error||'/'||v_error;
      end if;
    end if;   
   
end lp_validar_moneda;
  
--Validar detalles de la operación
procedure lp_validar_operacion(p_bco_emisor in number,
                               p_nro_cheque in number,
                               p_ok in out boolean) is
   v_error varchar2(300);
   v_fec_envio date;
   v_fec_remitido date;
   v_dummy varchar2(1);
   
   --Datos del cheque
   v_monto cc_che_enviados.monto%type;
   v_estado cc_che_enviados.estado%type;
   v_moneda cc_che_enviados.cod_moneda%type;
   v_nro_cuenta cc_che_enviados.nro_cuenta%type;
   v_cod_mod_cuenta ge_cuentas.cod_modulo%type;
begin
   
    v_error := null;
    
    --Obtener la ultima fecha de envio
    select max(fec_envio) 
      into v_fec_envio
      from cc_che_enviados
     where cod_banco = p_bco_emisor
       and estado <> 'D'
       and nro_cheque = p_nro_cheque;
    
    --Si no tiene fecha de envio se busca fecha de carga.   
    if v_fec_envio is null then
      select max(fecha) 
        into v_fec_envio
        from cc_che_enviados
       where cod_banco = p_bco_emisor
         and estado <> 'D'
         and nro_cheque = p_nro_cheque;      
    end if;   
    
    ---
    select max(fecha) 
      into v_fec_remitido
      from cc_che_remitidos
     where cod_banco = p_bco_emisor
       and nro_cheque = p_nro_cheque
       and cod_cau_devolucion is null
       --and cod_oficina = v_cod_oficina;
       and cod_oficina = v_cdofcam;
       
    --Traer Datos de cc_che_remitidos
    if v_fec_remitido is not null and (v_fec_remitido > v_fec_envio or v_fec_envio is null) then
        begin
          select monto, 'E', pag_gen.fu_obt_mon_local
            into v_monto, v_estado, v_moneda
            from cc_che_remitidos
           where nro_cheque = p_nro_cheque
             and cod_banco = p_bco_emisor
             and cod_cau_devolucion is null
             --and cod_oficina = v_cod_oficina
             and cod_oficina = v_cdofcam
              and fecha = (select max(fecha) --Porque pueden haber varias devoluciones
                            from cc_che_remitidos
                           where cod_banco = p_bco_emisor
                             and nro_cheque = p_nro_cheque
                              and cod_cau_devolucion is null
                             --and cod_oficina = v_cod_oficina
                             and cod_oficina = v_cdofcam
                             );
              
         exception
            when no_data_found then
               v_error := 'Cheque no registrado o ya fue devuelto. No puede ser devuelto';
              p_ok := false;
            when others then
               v_error := 'Error al buscar en cc_che_remitidos '||sqlerrm;
              p_ok := false;            
         end;
    --Traer datos de cc_che_enviados
    elsif v_fec_envio is not null and (v_fec_envio >= v_fec_remitido or v_fec_remitido is null) then
       begin
          select monto, estado, cod_moneda, nro_cuenta
            into v_monto, v_estado, v_moneda, v_nro_cuenta
            from cc_che_enviados
           where nro_cheque = p_nro_cheque
             and cod_banco = p_bco_emisor
             and estado <> 'D'
              and fecha = (select max(fecha) --Porque pueden haber varias devoluciones
                            from cc_che_enviados
                           where cod_banco = p_bco_emisor
                             and estado <> 'D'
                             and nro_cheque = p_nro_cheque);
        exception
            when no_data_found then
               v_error := 'Cheque no registrado o ya fue devuelto. No puede ser devuelto';
              p_ok := false;
           when others then
               v_error := 'Error al buscar en cc_che_enviados '||sqlerrm;
              p_ok := false;            
        end;
         
         --Verificar que no sea un Cobro de Préstamos , 06/07/2010
         if v_nro_cuenta is not null then
           begin
              select cod_modulo
                into v_cod_mod_cuenta
                from ge_cuentas c
               where c.nro_cuenta = v_nro_cuenta;
           exception
             when no_data_found then
               null;
           end;      
           if v_cod_mod_cuenta = 6 then
              v_error := 'Cheque ingresado por Cobro de Préstamos. Debe utilizar la opción de Cheques Devueltos';
              p_ok := false;              
           end if; 
         end if;
         
    --Buscar en ge_che_custodias
    else  
      begin
        select monto, estado, cod_moneda
          into v_monto, v_estado, v_moneda
          from ge_che_custodias
         where cod_banco = p_bco_emisor
           and nro_cheque = p_nro_cheque
           and estado in ('A','E')
           and rownum = 1;
         --Es un Cheque Descontado, no se puede devolver por este programa.. 06/07/2010  
         v_error := 'Cheque ingresado por Descuento de Cheques. Debe utilizar la opción de Cheques Devueltos';
         p_ok := false;     
       exception
         when too_many_rows then  
            v_error := 'Cheque duplicado para el Banco, verifique en GE_CHE_CUSTODIAS';
            p_ok := false;
         when no_data_found then
            v_error := 'Cheque no registrado o ya fue devuelto. No puede ser devuelto';
            p_ok := false;
         when others then
            v_error := 'Error al recuperar datos del cheque de GE_CHE_CUSTODIAS '||sqlerrm;
            p_ok := false;                              
       end;                   
    end if;
    
    --Se encontro el cheque, validar datos de la operación
    if v_error is null then
      --Validar monto
      if clrch.monto != v_monto then
         v_error := 'El monto del cheque en el archivo es distinto al monto enviado';
         p_ok := false;            
      end if;
      
      if clrch.tip_debito = 'C' then --Cuenta Cliente
        --Validar Saldo (Para Ahorros Vista y CDA)
        if pag_cta.g_ctas.cod_modulo=3 and pag_cta.g_ctas.cod_modalidad in (31,33,34,334)  then
           if clrch.monto > pag_cta.g_ctas.sal_total then
              v_error := 'Cuenta no tiene saldo suficiente para debitar';
              p_ok := false;            
            end if;      
         end if;
      elsif clrch.tip_debito = 'B' then --Rubro Contable
         begin
            select 'S'
              into v_dummy
              from cb_rubros cbr,cb_rub_oficinas cbo
             where cbo.cod_oficina = clrch.cod_oficina
               and cbo.cod_rubro   = clrch.cod_rubro
               and cbr.cod_rubro   = cbo.cod_rubro
               and cbr.imputable   = 'S'
               and cbr.cod_moneda  = clrch.cod_moneda;
          exception
            when no_data_found then
               p_ok := false;
               v_error := 'Cuenta Contable no habilitada para la oficina';  
          end;     
       end if; 
    end if;
    
    --Cargar mensaje de error
    if v_error is not null then
      if g_error is null then
         g_error := v_error;
      else
         g_error := g_error||'/'||v_error;
      end if;
    end if;
    
exception
  when others then
     v_error := substr('Error en lp_validar_operacion '||sqlerrm,1,300);
     p_ok := false;        
     if g_error is null then
        g_error := v_error;
     else
        g_error := g_error||'/'||v_error;
     end if;
end lp_validar_operacion;                      
                      

/****************************
 **   BLOQUE PRINCIPAL     **
 ****************************/                          
begin

  p_reg_err := 0;
  p_reg_tot := 0;

  if clrch_cur%isopen then
     close clrch_cur;
  end if;
  open clrch_cur;

  --Ciclo de Verificación
  <<proceso>>
  loop
    fetch clrch_cur into clrch;
    exit when clrch_cur%notfound;   
      
      pag_cta.g_ctas := null;
      g_error := null;
      g_tiperr := null;
      ok := true;
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
        if clrch.tip_debito = 'C' then
           pag_cta.pr_obt_cuenta(clrch.nro_cuenta);
        end if;   
      end if;
      
      --Validaciones
      lp_validar_banco(clrch.cod_bco_emisor,ok); --Código de Banco
      lp_validar_repetidos(clrch.cod_bco_emisor,clrch.cta_libradora,clrch.nro_cheque,clrch.cod_moneda,ok); --Cheques Repetidos
      
      --Para lo que no es de cambios
      if  nvl(v_es_cambio,'N')='N' then
       -- lp_validar_moneda(ok); --Moneda del Cheque  ** Truncamiento Fase 2 incluye M/E
        if clrch.tip_debito = 'C' then
           lp_validar_cuenta(ok); --Datos de la cuenta
        else
           lp_validar_cuenta_contable(ok); --Cuenta Contable
        end if;  
      end if;
      --Solo si pasa las anteriores se valida la operación
      
       --Para lo que no es de cambios
      if  nvl(v_es_cambio,'N')='N' then
          if ok then 
            lp_validar_operacion(clrch.cod_bco_emisor,clrch.nro_cheque,ok); --Datos de la Operación
            lp_validar_motivo(ok);
          end if;
      end if;      
      if ok then
         v_est_registro := 'P'; --Sin errores, se deja como Pendiente
      else
         v_est_registro := 'E'; --Marcar el registro con estado "E"(Error)
         p_reg_err := p_reg_err + 1;
         p_procesar := 'N';
      end if;
      
      if g_error is not null then
         g_error := 'ERROR: '||g_error;
      end if;   
      
      --Actualizar estado del registro y mensaje de error
      update cc_che_rechazados_tmp set msj_error=g_error,estado=v_est_registro where rowid = clrch.registro;
      
   end loop proceso;
   
   if clrch_cur%rowcount = 0 then
       Raise_application_error(-20002, 'No existen registros a ser procesados.');
   else
       p_reg_tot := clrch_cur%rowcount;
   end if;
   close clrch_cur;   

exception
  when others then
    raise_application_error(-20099, 'Error: '||replace(sqlerrm, 'ORA-',''));
end prc_ver_che_rch_cam;
/
