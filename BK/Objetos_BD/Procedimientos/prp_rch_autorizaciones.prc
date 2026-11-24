create or replace procedure IT.PRP_RCH_AUTORIZACIONES is
   Cursor c_aut_pedidos is 
   Select p.fecha,
          p.hora, 
          p.cod_usuario, 
          g.cod_modulo, 
          g.cod_transaccion, 
          g.nro_documento
    from ge_aut_pedidos p, ge_movimientos g
      where p.respuesta = 'P'
         and p.estado = 'S'
         and trunc(p.fec_insercion)= trunc(sysdate) 
         and p.cod_usuario = g.cod_usuario
         and p.hora = g.hora
         and p.fecha = g.fecha
         and g.nro_secuencia = 1
         and (g.cod_modulo = 6 OR (g.cod_modulo = 9 AND g.cod_mod_padre = 6));

  v_respuesta ge_aut_pedidos.respuesta%type;
  v_estado    ge_aut_pedidos.estado%type;
  v_cod_usu_autorizador ge_aut_pedidos.cod_usu_autorizador%type;
  ----
Procedure PR_ELI_AUTORIZACIONES is
-- Eliminacion de autorizaciones pendientes del dia
 begin
   delete from ge_aut_pedidos gaped
    where gaped.respuesta = 'P'
      and gaped.estado = 'S'
      and trunc(gaped.fec_insercion) = trunc(sysdate)
      and not exists
            (Select 1
             from ge_movimientos
            where fecha = pag_cal.fu_obt_fec_actual(1)
              and hora = gaped.hora
              and cod_usuario = gaped.cod_usuario
              and nro_secuencia = 1);
 end;

begin
  v_respuesta := 'R';
  v_estado    := 'A'; -- anulado
  v_cod_usu_autorizador := user;

  begin pre_ini_aplicacion; pae_cnf.g_cod_modulo :=1; end;
  
  PR_ELI_AUTORIZACIONES;
  
  FOR r1 in c_aut_pedidos LOOP
      IF r1.cod_modulo = 6 and r1.cod_transaccion = 100 THEN 
           --- Actualiza el estado de la solicitud.
          update pr_solicitudes
             set estado = 'R',
                 aut_pendiente = 'N'
           where nro_solicitud = r1.nro_documento
             and estado not in ('A','L');
           pag_aut.pr_anu_movimiento(r1.cod_usuario, r1.fecha, r1.hora);          
         --- Actualiza el estado del pedido de Autorizacion.        
          update ge_aut_pedidos
             set respuesta = v_respuesta,
                 estado = v_estado,
                 cod_usu_autorizador = v_cod_usu_autorizador
           where cod_usuario = r1.cod_usuario
             and fecha = r1.fecha
             and hora = r1.hora
             and respuesta = 'P'
             and estado = 'S';   
        END IF; 
   END LOOP;       
end PRP_RCH_AUTORIZACIONES;
