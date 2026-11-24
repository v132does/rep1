create or replace procedure it.prc_inh_cli_che_devueltos is
  v_fec_hoy        date := pag_cal.fu_obt_fec_actual(4);
  v_hora           ge_movimientos.hora%type := fug_ini_hora(sysdate,'HH24:MI:SS');
  v_cau_bloqueo    ge_causales.cod_causa%type := fug_obt_pardinamico('COD_CAU_BLO_CTA_IF');
  v_nro_secuencia  ge_movimientos.nro_secuencia%type := 0;
  v_cod_error      number;
  v_cau_inhibicion ge_causales.cod_causa%type;
  v_fec_vto        date; 
  v_inhibicion     varchar2(1) := 'N';
  v_exi_inhi        varchar2(1) := 'N';
  v_can_formales   number := nvl(fug_obt_pardinamico('CAN_FAL_FORMALES',4,null,null,null),5);
  v_can_ins_fondo  number := nvl(fug_obt_pardinamico('CAN_FAL_INSUFICIENCIA',4,null,null,null),5);
  v_fec_implementacion date := nvl(fug_obt_pardinamico('FEC_INH_AUTOMATICA'),to_date('01/01/1990','dd/mm/yyyy')); 
  v_men_error      varchar2(4000);
  v_det_error      varchar2(4000);
  v_persona        cc_che_dev_firmantes.cod_persona%type;
  v_detalle        ge_per_inhibidas.detalle%type ;
      
  cursor c_che_dev is
   select distinct c.cod_modulo, c.cod_modalidad, c.cod_moneda, 
          c.cod_oficina, t.tipo, t.cantidad, t.cod_persona,  d.cod_causa
     from cc_cta_corrientes c,
          cc_che_devueltos d,
          cc_che_dev_firmantes f,
          cc_che_dev_totales t                      
    where c.nro_cuenta = d.nro_cuenta
      and d.nro_cuenta = f.nro_cuenta 
      and d.nro_cheque = f.nro_cheque
      and f.cod_persona = t.cod_persona
      and t.tipo = d.tipo   
      and t.tipo in ('F','C','I')
      and (  (t.tipo = 'F' and
              t.cantidad >= v_can_formales)                
        or    (t.tipo = 'I' and
              t.cantidad >= v_can_ins_fondo)                   
        or     (t.tipo = 'C')
                )
      and d.fec_insercion >= nvl(t.fec_ult_regularizacion, v_fec_implementacion)  
   order by  t.cod_persona, t.tipo;    
 
  procedure lp_ins_log_errores(p_nro_cuenta   ge_cuentas.nro_cuenta%type,
                               p_cod_persona  cc_che_dev_firmantes.cod_persona%type,
                               p_det_error varchar2) is
    pragma autonomous_transaction;
  begin
    insert into cc_log_errores(cod_programa, fecha, cod_persona, nro_cuenta, det_error)
    values ('PRC_INH_CLI_CHE_DEVUELTOS', v_fec_hoy, p_cod_persona, p_nro_cuenta, p_det_error);
    
    commit;
  exception
    when others then 
       null;
  end; 
  --Procedimiento de bloqueo de cuentas
  procedure lp_ins_bloqueo is
      v_nro_doc        number;                            
      r_gmovimiento    ge_movimientos%rowtype;
      v_can_dias       number := fug_obt_pardinamico('CAN_DIAS_BLOQUEO',4); 
      v_principal      ge_cta_clientes.cod_persona%type;
      v_tip_persona    ba_personas.tipo%type;
      v_bloqueo        varchar2(1) := 'N';
      v_est_cuenta     ge_cuentas.estado%TYPE;
      v_cau_inh        ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('COD_CAU_INH_BLO_CTA');
      v_bloquear       varchar2(1) := 'N';
      
      cursor c_inh is 
       select g.nro_cuenta, g.cod_modulo, g.cod_modalidad, g.cod_oficina, c.cod_moneda, g.cod_persona, g.relacion
         from ge_cta_clientes g, ge_cuentas c
        where g.nro_cuenta = c.nro_cuenta
          and g.cod_modulo = c.cod_modulo
          and g.cod_modalidad = c.cod_modalidad
          and g.cod_modulo = 4
          and g.cod_modalidad = 41
          and c.estado not in ('T','C')  
          and g.cod_persona in (select i.cod_persona
                                  from ge_per_inhibidas i
                                 where instr(v_cau_inh,','||i.cod_causa||',') > 0
                                   and i.estado = 'I'
                                   and i.fec_inicio = v_fec_hoy
                                   and v_fec_hoy <= i.fec_vencimiento);   
     
  begin 
     for r_inh in c_inh loop
        v_est_cuenta := null;
        v_bloqueo := null;
        v_tip_persona := null;
        v_principal := null;
        v_bloquear := null;
                
        --obtener datos de la cuenta actual
        pag_cta.pr_obt_cuenta(r_inh.nro_cuenta);
        v_est_cuenta := pag_cta.fu_obt_est_cuenta;
              
        if v_est_cuenta <> 'T' then
           v_bloquear := fuc_ver_inh_che_devueltos(r_inh.nro_cuenta);                     
           
           if nvl(v_bloquear,'N') = 'S' THEN
             --bloquear todas las ctas. ctes. de la persona principal..
             r_gmovimiento.cod_usuario     := null;
             r_gmovimiento.hora            := null; 
             r_gmovimiento.nro_secuencia   := null; 
             r_gmovimiento.cod_modulo      := null;
             r_gmovimiento.cod_modalidad   := null;
             r_gmovimiento.cod_oficina     := null;
             r_gmovimiento.nro_cuenta      := null;
             r_gmovimiento.cod_moneda      := null;
             r_gmovimiento.fec_valor       := null;
             r_gmovimiento.fecha           := null;
             r_gmovimiento.cod_tra_padre   := null;
             r_gmovimiento.cod_transaccion := null;
             r_gmovimiento.est_cuenta      := null;
             r_gmovimiento.estado          := null;
             r_gmovimiento.cod_ofi_origen  := null;
             r_gmovimiento.reversado       := null;
             r_gmovimiento.emi_aviso       := null;
             r_gmovimiento.protegido       := null;
             r_gmovimiento.cod_mod_padre   := null;
             r_gmovimiento.cod_mad_padre   := null;
             r_gmovimiento.monto           := null;
             r_gmovimiento.nro_documento   := null;
             r_gmovimiento.cod_causa       := null;
             r_gmovimiento.cod_tasa        := null;
             r_gmovimiento.val_tasa        := null;
                
             begin
                select s_nro_bloqueo.nextval into v_nro_doc from dual;
             exception
                when others then
                   v_nro_doc := 1;
             end; 
                           
             --insertar mov. de cambio de estado de la cuenta por bloqueo 
             v_nro_secuencia := v_nro_secuencia + 1; 
             if v_nro_secuencia = 995 then
                v_hora := pag_gen.fu_obt_sig_segundo(v_hora);
                v_nro_secuencia := 1;
             end if;
              
             update ge_bloqueos c
                set fec_inicio      = v_fec_hoy,    
                    fec_fin         = v_fec_hoy + nvl(v_can_dias,0),
                    cod_causa       = v_cau_bloqueo,           
                    hor_inicio      = v_hora,
                    tipo            = 'T'
              where nro_cuenta      = r_inh.nro_cuenta
                and nro_documento   = v_nro_doc;  
                       
             if sql%notfound then 
                begin
                   insert into ge_bloqueos
                     (nro_cuenta, nro_documento, fec_inicio, cod_causa, fec_fin,
                      hor_inicio, tipo, tip_bloqueo, observacion)
                   values
                     (r_inh.nro_cuenta, v_nro_doc, v_fec_hoy, v_cau_bloqueo, v_fec_hoy + v_can_dias, 
                      v_fec_hoy, 'T', 'A', 'Bloqueo de Cta. por Rechazo de Cheques por Insuf. de Fondos');
                    
                   v_bloqueo := 'S';             
                exception
                   when others then
                      v_bloqueo := 'N'; 
                      v_men_error := '103 - No se pudo bloquear la cuenta '||r_inh.nro_cuenta||'. '|| sqlerrm;
                      lp_ins_log_errores(r_inh.nro_cuenta, 
                                         r_inh.cod_persona,         
                                         substr(v_men_error, 1, 4000));                   
                end;
             else
                v_bloqueo := 'S';  
             end if;
              
             if v_bloqueo = 'S' then         
                begin
                   --se actualiza el estado de la cuenta
                   pag_cta.pr_act_est_cta(r_inh.nro_cuenta,
                                         r_inh.cod_modalidad,
                                         'T',
                                         v_fec_hoy);                                 
                             
                   r_gmovimiento.cod_usuario     := user;
                   r_gmovimiento.hora            := v_hora; 
                   r_gmovimiento.nro_secuencia   := v_nro_secuencia; 
                   r_gmovimiento.cod_modulo      := r_inh.cod_modulo;
                   r_gmovimiento.cod_modalidad   := r_inh.cod_modalidad;
                   r_gmovimiento.cod_oficina     := r_inh.cod_oficina;  
                   r_gmovimiento.nro_cuenta      := r_inh.nro_cuenta;
                   r_gmovimiento.cod_moneda      := r_inh.cod_moneda;
                   r_gmovimiento.fec_valor       := v_fec_hoy;  
                   r_gmovimiento.fecha           := v_fec_hoy;
                   r_gmovimiento.cod_tra_padre   := 306;
                   r_gmovimiento.cod_transaccion := 408;
                   r_gmovimiento.est_cuenta      := 'T';
                   r_gmovimiento.estado          := 'N';
                   r_gmovimiento.cod_ofi_origen  := r_inh.cod_oficina; 
                   r_gmovimiento.reversado       := 'N';
                   r_gmovimiento.emi_aviso       := 'N';
                   r_gmovimiento.protegido       := 'N';
                   r_gmovimiento.cod_mod_padre   := r_inh.cod_modulo;
                   r_gmovimiento.cod_mad_padre   := r_inh.cod_modalidad;
                   r_gmovimiento.monto           := null;
                   r_gmovimiento.nro_documento   := v_nro_doc;
                   r_gmovimiento.cod_causa       := v_cau_bloqueo;
                   r_gmovimiento.cod_tasa        := null;
                   r_gmovimiento.val_tasa        := null;
                                      
                   pag_gen.pr_ins_ge_movimiento(r_gmovimiento);  
                exception
                   when others then
                      v_men_error := '104 - Error en el cambio de estado de la cuenta '||r_inh.nro_cuenta;
                      lp_ins_log_errores(r_inh.nro_cuenta, 
                                         r_inh.cod_persona,         
                                         substr(v_men_error, 1, 4000));
                end; 
             end if; 
           end if;              
              
        end if;
     end loop;                          
  end; 
  
  procedure lp_ins_circuito (p_cod_circuito in wf_circuitos.cod_tip_circuito%type,
                             p_cod_persona  in ge_per_inhibidas.cod_persona%type) is
    v_referencia   wf_circuitos.referencia%type;   
  begin
     select s_cod_autorizacion.nextval into v_referencia from dual; 
            
     v_cod_error := paw_cir.fu_ini_circuito(p_cod_circuito, v_referencia, p_cod_persona);
        
     if v_cod_error <> 0 then
        v_men_error := '105 - Error al generar Circuito. ' || sqlerrm;
        lp_ins_log_errores(null, 
                           v_persona,         
                           substr(v_men_error, 1, 4000));   
     end if;     
  end;

  function lf_det_cheques (p_cod_persona in ba_personas.cod_persona%type,
                           p_tipo        in cc_che_dev_totales.tipo%type)                    
  return varchar2 is    
    v_detalle   ge_per_inhibidas.detalle%type default null;   
                       
    cursor c_che is
      select distinct f.nro_cheque, d.monto, d.cod_moneda
        from cc_che_devueltos d,
             cc_che_dev_firmantes f,
             cc_che_dev_totales t                      
       where d.nro_cuenta = f.nro_cuenta 
         and d.nro_cheque = f.nro_cheque
         and f.cod_persona = t.cod_persona
         and t.tipo = d.tipo   
         and (  (t.tipo = 'F' and
                 t.cantidad >= v_can_formales)                
           or    (t.tipo = 'I' and
                 t.cantidad >= v_can_ins_fondo)                   
           or     (t.tipo = 'C')
                   )
         and d.fec_insercion >= nvl(t.fec_ult_regularizacion, v_fec_implementacion) 
         and t.tipo = p_tipo         
         and t.cod_persona = p_cod_persona;             
  begin
     for r_che in c_che loop
        v_detalle := v_detalle || ' - '|| r_che.nro_cheque  ||' '|| r_che.cod_moneda ||' '||r_che.monto ;       
     end loop; 
     
     return v_detalle;
  end;                         
                              
  procedure lp_ins_inhibicion(p_cod_persona in ba_personas.cod_persona%type,
                              p_causa       in ge_per_inhibidas.cod_causa%type,
                              p_inhibicion  out varchar2)
  is
    v_fec_vto        date;   
    v_nro_orden      ge_per_inhibidas.nro_orden%type := 0;  
    v_cod_banco      ge_bancos.cod_banco%type := fug_obt_cod_banco;
    
  begin    
     p_inhibicion := 'N';   
     v_fec_vto := v_fec_hoy + fug_obt_parcausales(p_causa,'PLA_INHABILITACION');
     -- actualizo las inhibiciones, si existe y no se venció aún si no se inserta
     update ge_per_inhibidas a
        set a.estado         = 'I',
            a.detalle        = substr(a.detalle||' '||v_detalle,1,2000)
      where cod_persona      = p_cod_persona
        and cod_causa        = p_causa
        and a.estado         = 'I'
        and a.fec_vencimiento >= v_fec_hoy; 
         
     if sql%notfound then
        -- numerador
        select nvl(max(nro_orden),0) + 1
          into v_nro_orden
          from ge_per_inhibidas a
         where cod_persona = p_cod_persona;  
              
        -- no esta en inhibidos
        insert into ge_per_inhibidas
          (cod_persona, nro_orden, cod_causa, fec_inicio, 
           origen, cod_banco, detalle, estado, fec_vencimiento, situacion)
        values
          (p_cod_persona, nvl(v_nro_orden,1), p_causa, v_fec_hoy,
           'Cheques Devueltos', v_cod_banco, 'Inh. automatica por ch. devueltos. '||v_detalle, 'I', v_fec_vto, 'P');
           
        p_inhibicion := 'S';  
     else 
        p_inhibicion := 'S';      
     end if;
  exception
     when others then
        p_inhibicion := 'N';
        v_men_error := '106 - Error inhibir a la persona '||p_cod_persona||'. '|| sqlerrm;
        lp_ins_log_errores(null, 
                           v_persona,         
                           substr(v_men_error, 1, 4000));         
  end;    
begin
  begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;  
  --el cursor solo trae las cuentas que superan los límites establecidos para los casos de faltas formales 
  --e insuficienca de fondos, teniendo en cuenta los parametros CAN_FAL_FORMALES y CAN_FAL_INSUFICIENCIA
  --los casos de cancelacion no estan limitados
  for r_che_dev in c_che_dev loop   
     v_persona := r_che_dev.cod_persona;
      
     if r_che_dev.tipo = 'I' then  
        --inhibicion
        v_cau_inhibicion := fue_obt_val_max_referencia('COD_TIP_DEVOLUCION','I');   --obtengo el cod. de inhibicion por ins. de fondos
           
        begin
           select distinct('S')
             into v_exi_inhi
             from ge_per_inhibidas i 
            where i.cod_persona = r_che_dev.cod_persona
              and i.cod_causa = v_cau_inhibicion
              and i.estado = 'I'
              and i.fec_vencimiento >= v_fec_hoy;              
        exception
           when no_data_found then
              v_exi_inhi := 'N';
        end;
              
        if v_exi_inhi = 'N' then
           v_detalle := substr(lf_det_cheques(r_che_dev.cod_persona, r_che_dev.tipo),1,2000);
           lp_ins_inhibicion (r_che_dev.cod_persona,  v_cau_inhibicion,v_inhibicion);
              
           if nvl(v_inhibicion,'N') = 'S' then
              --generacion del WF 
              lp_ins_circuito(400, r_che_dev.cod_persona);                        
           end if;
        end if;               
        
     elsif r_che_dev.tipo = 'F' then 
        lp_ins_circuito(402, r_che_dev.cod_persona);
             
     elsif r_che_dev.tipo = 'C' then
        --inhibicion
        v_cau_inhibicion := fue_obt_val_max_referencia('COD_TIP_DEVOLUCION','C');  --obtengo el cod. de inhibicion por ins. de fondos
         
        begin
           select distinct('S')
             into v_exi_inhi
             from ge_per_inhibidas i 
            where i.cod_persona = r_che_dev.cod_persona
              and i.cod_causa = v_cau_inhibicion
              and  i.fec_vencimiento >= v_fec_hoy;              
        exception
           when no_data_found then
              v_exi_inhi := 'N';
        end;
        
        if v_exi_inhi = 'N' then    
           v_detalle := substr(lf_det_cheques(r_che_dev.cod_persona, r_che_dev.tipo),1,2000);
           lp_ins_inhibicion (r_che_dev.cod_persona, v_cau_inhibicion,v_inhibicion);       
        
           --generacion del WF 
           if nvl(v_inhibicion,'N') = 'S' then
              lp_ins_circuito(401, r_che_dev.cod_persona); 
           end if;
        end if;           
     end if;
     
     v_exi_inhi := 'N';
     v_inhibicion := 'N';
     v_detalle := null;
  end loop;
  
  --se inicia el bloqueo de cuenta
  lp_ins_bloqueo;
  
exception
  when others then
    v_det_error := dbms_utility.format_error_backtrace || ' ' ||
                   dbms_utility.format_error_stack;
  
    lp_ins_log_errores(null,
                       v_persona,
                       substr(v_det_error, 1, 4000));
end prc_inh_cli_che_devueltos;
/
