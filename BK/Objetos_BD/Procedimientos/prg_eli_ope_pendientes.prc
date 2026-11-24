create or replace procedure it.prg_eli_ope_pendientes is
  /* Elimina las operaciones pendientes de confirmacion por operaciones */
  cursor mov_pen is
    select distinct fecha,hora,cod_usuario,estado,nro_caja,nro_documento 
      from ge_movimientos mov
      where mov.estado = 'P' 
        and mov.reversado = 'N'
        and not exists (select 1 
                      from ge_aut_pedidos ped
                     where ped.cod_usuario = mov.cod_usuario
                       and ped.fecha = mov.fecha
                       and ped.hora = mov.hora);
  
  v_hora          ge_movimientos.hora%type;        
  v_cod_mod_padre ge_movimientos.cod_mod_padre%type;
  v_cod_mad_padre ge_movimientos.cod_mad_padre%type;
  v_cod_tra_padre ge_movimientos.cod_tra_padre%type;                
begin
  --reversar los movimientos pendientes no confirmados
  v_hora := to_char(sysdate,'hh24:mi:ss');
  for mov in mov_pen loop
    v_hora      := pag_gen.fu_obt_sig_segundo(v_hora);
    
    --Obtener la transaccion padre del movimiento
    select cod_mod_padre,cod_mad_padre,cod_tra_padre
     into v_cod_mod_padre,v_cod_mad_padre,v_cod_tra_padre
     from ge_movimientos 
    where reversado = 'N'
      and fecha       = mov.fecha
      and hora        = mov.hora
      and cod_usuario = mov.cod_usuario
      and rownum = 1; 
      
  	prg_rev_operacion(mov.fecha,
                      mov.hora,
                      mov.cod_usuario,
                      v_cod_mod_padre,
                      v_cod_mad_padre,
                      v_cod_tra_padre,--indica la operación
                      user, ---cod_usu_reversion
                      v_hora,
                      'N',
                      'Rechazado en forma automatica'); --Es nocturno.
    if pag_cta.fu_obt_cod_error() <> 0 then
    	 raise_application_error(-20000,pag_cta.fu_obt_cod_error()||' - '||pag_cta.fu_obt_msj_error());
    end if;                                        
  end loop;
exception
  when others then
    If sqlcode = -20000 then
      raise;
    else
      raise_application_error(-20000,'Al cancelar en forma automatica '||sqlerrm);  
    End if;
end prg_eli_ope_pendientes;
/

