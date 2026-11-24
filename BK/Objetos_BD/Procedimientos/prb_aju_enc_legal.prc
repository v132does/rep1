CREATE OR REPLACE PROCEDURE IT.PRB_AJU_ENC_LEGAL ( p_nro_referencia sb_enc_circular254.nro_referencia%type,
                                               p_fecha sb_enc_circular254.fecha%type,
                                               p_tip_accion varchar2 default 'A' ) is
  rv_sbec sb_enc_circular254%rowtype;
  v_existe varchar2(1);
  v_nro_registro number := 0; 
  cursor c_cursor is
    select a.nro_registro, a.cod_moneda, a.cod_cuenta, 
           a.cod_subcuenta, a.plazo, a.rango, a.can_cuenta, 
           a.importe, a.cta_departamento, a.enc_exonerado,
           'SBEC' origen
    from sb_enc_circular254 a 
    where a.fecha = p_fecha
  union 
    select a.nro_registro, a.cod_moneda, a.cod_cuenta, 
           a.cod_subcuenta, a.plazo, a.rango, a.can_cuenta, 
           a.importe, a.cta_departamento, a.enc_exonerado,
           'SBECT' origen
    from sb_enc_circular254_tmp a 
    where a.fecha = p_fecha
    and a.nro_registro not in( select a.nro_registro
                                 from sb_enc_circular254 a 
                                where a.fecha = p_fecha )                             
    order by 1;        
begin   
 
  if nvl(p_tip_accion,'A') = 'A' then   
  
    select a.cod_moneda, a.cod_cuenta, a.cod_subcuenta, 
           a.plazo, a.rango, a.can_cuenta, a.importe,
           a.cta_departamento, a.enc_exonerado
      into rv_sbec.cod_moneda, rv_sbec.cod_cuenta, rv_sbec.cod_subcuenta, 
           rv_sbec.plazo, rv_sbec.rango, rv_sbec.can_cuenta, rv_sbec.importe,
           rv_sbec.cta_departamento, rv_sbec.enc_exonerado
      from sb_enc_circular254_tmp a
     where nro_registro = p_nro_referencia
       and fecha = p_fecha;  
	   
    begin 
	
      select 'S'
        into v_existe
        from sb_enc_circular254 a
       where a.nro_registro = p_nro_referencia
         and a.fecha = p_fecha;
            
      update sb_enc_circular254 a
         set a.cod_moneda = rv_sbec.cod_moneda,
             a.cod_cuenta = rv_sbec.cod_cuenta,
             a.cod_subcuenta = rv_sbec.cod_subcuenta,
             a.plazo = rv_sbec.plazo,
             a.rango = rv_sbec.rango,
             a.can_cuenta = rv_sbec.can_cuenta,
             a.importe = rv_sbec.importe,
             a.cta_departamento = rv_sbec.cta_departamento,
             a.enc_exonerado = rv_sbec.enc_exonerado
       where a.nro_registro = p_nro_referencia
         and a.fecha = p_fecha; 
		 
    exception
      when no_data_found then
        rv_sbec.fecha := p_fecha;
        rv_sbec.nro_registro := p_nro_referencia;
        
        insert into sb_enc_circular254( fecha, nro_registro, cod_moneda, cod_cuenta, 
                                        cod_subcuenta, plazo, rango, can_cuenta, 
                                        importe, cta_departamento, enc_exonerado )
        values( rv_sbec.fecha, rv_sbec.nro_registro, rv_sbec.cod_moneda, rv_sbec.cod_cuenta, 
                rv_sbec.cod_subcuenta, rv_sbec.plazo, rv_sbec.rango, rv_sbec.can_cuenta, 
                rv_sbec.importe, rv_sbec.cta_departamento, rv_sbec.enc_exonerado );
    end;   
	
    update sb_enc_circular254_tmp a  
       set a.estado = 'A',
           a.usu_aprobacion = substr(USER,1,10),
           a.fec_aprobacion = SYSDATE        
     where a.nro_registro = p_nro_referencia
       and a.fecha = p_fecha;
       
    -- CNFDELEG-1 / RABP-CNF / 06-2016 --
    update ge_par_dinamicos
       set val_parametro = to_char(p_fecha,'dd/mm/yyyy')
     where parametro = 'FEC_REP_ENC_MENSUAL';

    pas_bcp.pr_gen_rep_enc_mensual;   
    
	   
  elsif p_tip_accion = 'R' then

    update wf_cir_tareas a
       set a.estado = 'R',
           a.fec_finalizacion = SYSDATE
     where cod_circuito = ( select cod_circuito 
                              from wf_circuitos 
                             where referencia = to_char(p_nro_referencia)
                               and cod_tip_circuito = 998 
                               and estado not in ('F','C') );
    
    update wf_circuitos a
       set a.estado = 'F',
           a.fec_fin = SYSDATE
     where referencia = to_char(p_nro_referencia)
       and cod_tip_circuito = 998
       and estado not in ('F','C'); 
                            
    delete sb_enc_circular254_tmp a      
     where a.nro_registro = p_nro_referencia
       and a.fecha = p_fecha;
  
  else
    update wf_cir_tareas a
       set a.estado = 'C',
           a.fec_finalizacion = SYSDATE
     where cod_circuito = ( select cod_circuito 
                              from wf_circuitos 
                             where referencia = to_char(p_nro_referencia)
                               and cod_tip_circuito = 998 
                               and estado not in ('F','C') );
    
    update wf_circuitos a
         set a.estado = 'C',
             a.fec_fin = SYSDATE
       where referencia = to_char(p_nro_referencia)
         and cod_tip_circuito = 998
         and estado not in ('F','C'); 
                              
      delete sb_enc_circular254_tmp a      
       where a.nro_registro = p_nro_referencia
         and a.fecha = p_fecha;
  end if;  
   
  if p_tip_accion != 'C' then
    --Reenumerar--          
    for r in c_cursor loop
      v_nro_registro := v_nro_registro + 1;
      if v_nro_registro != r.nro_registro then
        if r.origen = 'SBEC' then          
          update sb_enc_circular254 a
             set a.nro_registro = v_nro_registro
           where a.nro_registro = r.nro_registro
             and a.fecha = p_fecha;
          
          update sb_enc_circular254_tmp a
             set a.nro_registro = v_nro_registro
           where a.nro_registro = r.nro_registro
             and a.fecha = p_fecha
             and a.estado = 'A';
             
          update wf_circuitos c
             set c.referencia = to_char(v_nro_registro)
           where c.referencia = to_char(r.nro_registro)
             and trunc(c.fec_insercion) = trunc(sysdate)
             and c.cod_tip_circuito = 998
             and estado = 'F';      
        else          
          update sb_enc_circular254_tmp a
             set a.nro_registro = v_nro_registro
           where a.nro_registro = r.nro_registro
             and a.fecha = p_fecha
             and a.estado = 'P';
          
          update wf_circuitos c
             set c.referencia = to_char(v_nro_registro)
           where c.referencia = to_char(r.nro_registro)
             and trunc(c.fec_insercion) = trunc(sysdate)
             and c.cod_tip_circuito = 998
             and estado not in ('F','C');                    
        end if;                         
      end if;
    end loop;
  end if;  
  
exception
  when others then
    raise_application_error(-20000, 'ERROR al Actualizar Nro. Registro : '||p_nro_referencia||
                                    '. Fecha : '||to_char(p_fecha,'DD/MM/YYYY')||'. '||SQLERRM);                               
end;
/

