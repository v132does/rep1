create or replace procedure IT.PRA_RCH_AUTORIZACIONES is
   Cursor c_aut_pedidos is
   Select p.fecha,
          p.hora,
          p.cod_usuario,
          p.mensaje,          
          g.cod_modalidad  
    from ge_aut_pedidos p, ge_movimientos g
      where p.respuesta = 'P'
         and p.estado = 'S'
         and trunc(p.fec_insercion)= trunc(sysdate)
         and p.cod_usuario = g.cod_usuario
         and p.hora = g.hora
         and p.fecha = g.fecha
         and g.nro_secuencia = 1
         and (g.cod_modulo = 3 OR (g.cod_modulo = 9 AND g.cod_mod_padre = 3));

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
--
PROCEDURE P_ACT_TASA_DE_PIZARRA_CDA(p_cod_usuario in varchar2,
                                    p_fecha in date,
                                    p_hora in varchar2,
                                    p_mensaje in varchar2) IS
   -- Cursor de movimientos en 'X' para el pedido
   CURSOR c_mov_pedidos IS
   SELECT nro_cuenta, cod_tasa, rowid
     FROM ge_movimientos
    WHERE cod_usuario = p_cod_usuario
      and fecha = p_fecha
      and hora = p_hora
      and cod_usu_autorizador is null
      and cod_autorizacion is null
      and estado = 'X';
v_rowid varchar2(50);
v_cod_tasa varchar2(5);
BEGIN
   for reg in c_mov_pedidos loop
      -- Tomo la tasa anterior
      v_cod_tasa := substr(p_mensaje,instr(p_mensaje,'(Codigo ',-1)+ 8,4);
      v_cod_tasa := substr(v_cod_tasa,1,instr(v_cod_tasa,')')-1);
      if v_cod_tasa > 0 then
         select rowid into v_rowid
           from ah_cta_certificados
          where nro_cuenta = reg.nro_cuenta
            for update nowait;
         update ah_cta_certificados
            set cod_tasa = v_cod_tasa
          where rowid = v_rowid;
      end if;
      -- Obs. La autorizacion se actualiza a utilizada en el trigger de ah_cta_certifcados
      -- y en el de ge_autorizaciones confirma el movimiento, por eso no es necesario realizar
      -- dichos pasos aqui.
   end loop;
 exception
   when no_data_found then
      Raise_Application_Error(-20000,'Cuenta a actualizar no existe!. Verifique ');
   when others then
      if sqlcode = -54 then  -- registro bloqueado por otro usuario
         Raise_Application_Error(-20001,'Registro utilizado por otro Usuario. Vuelva a intentarlo.');
      elsif sqlcode <= -20000 then
         Raise;
      Else
         Raise_Application_Error(-20002,'Al actualizar cuenta '||sqlerrm);
      end if;
END;
----
BEGIN
  v_respuesta := 'R';
  v_estado    := 'A'; -- anulado
  v_cod_usu_autorizador := user;
  
  BEGIN pre_ini_aplicacion; pae_cnf.G_COD_MODULO := 1; END;   
  PR_ELI_AUTORIZACIONES;
  FOR r1 IN c_aut_pedidos LOOP
     IF r1.cod_modalidad = 33 THEN
         -- actualizo la tasa del cda por defecto
         P_ACT_TASA_DE_PIZARRA_CDA(r1.cod_usuario, r1.fecha, r1.hora, r1.mensaje);
         pag_aut.pr_anu_movimiento(r1.cod_usuario, r1.fecha, r1.hora);
     END IF;   
        --- Actualiza el estado del pedido de Autorizacion.
        Update ge_aut_pedidos
           set respuesta = v_respuesta,
               estado = v_estado,
               cod_usu_autorizador = v_cod_usu_autorizador
         where cod_usuario = r1.cod_usuario
           and fecha = r1.fecha
           and hora = r1.hora
           and respuesta = 'P'
           and estado = 'S';
  END LOOP;
END PRA_RCH_AUTORIZACIONES;
