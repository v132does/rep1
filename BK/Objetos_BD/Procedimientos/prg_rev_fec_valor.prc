CREATE OR REPLACE PROCEDURE IT.PRG_REV_FEC_VALOR
 IS
   v_fecha          ge_calendarios.fec_actual%type;
   v_hora           ge_movimientos.hora%type;
   v_cod_mod_padre  ba_modulos.cod_modulo%type;
   v_cod_mad_padre  ge_modalidades.cod_modalidad%type;
   v_cod_tra_padre  ge_transacciones.cod_transaccion%type;
   v_cod_mon_local  ba_monedas.cod_moneda%type;
   v_nro_secuencia  ge_movimientos.nro_secuencia%type;
   r_gmovi          ge_movimientos%rowtype;
   v_reversa varchar2(1);

   --- Cursor de movimientos con fecha valor no confirmados
   cursor pendientes is
   select distinct fecha, hora, cod_usuario
     from ge_movimientos a
    where fecha > fec_valor
      and fecha = v_fecha
      --and estado in ('J','P','X')
      and reversado ='N'
      and cod_usu_autorizador is null
    order by hora desc;--por si hay movimientos consecutivos

BEGIN
   --- Recuperar datos de fecha calendario
   v_fecha          := pag_cal.FU_OBT_FEC_ACTUAL(1);
   v_hora           := fug_ini_hora(sysdate,'HH24:MI:SS');
   for reg in pendientes loop
      begin
      select cod_mod_padre, cod_mad_padre, cod_tra_padre
        into v_cod_mod_padre, v_cod_mad_padre, v_cod_tra_padre
        from (
      select cod_mod_padre, cod_mad_padre, cod_tra_padre
        from ge_movimientos a
       where fecha = reg.fecha
         and hora = reg.hora
         and cod_usuario = reg.cod_usuario
       group by cod_mod_padre, cod_mad_padre, cod_tra_padre
       having count(*) = (select max(count(*))
                           from ge_movimientos b
                          where fecha = reg.fecha
                            and hora = reg.hora
                            and cod_usuario = reg.cod_usuario
                          group by cod_mod_padre, cod_mad_padre, cod_tra_padre))
        where rownum = 1;
      end;
      v_hora := pag_gen.FU_OBT_SIG_SEGUNDO(v_hora);
      -- verificar parámetros de la transacción
      v_reversa := fug_obt_pardinamico(v_cod_mod_padre, v_cod_mad_padre,null,null);
      if nvl(v_reversa,'X') = 'S' then
        --- reversar la operación
        prg_rev_operacion(reg.fecha,
                          reg.hora,
                          reg.cod_usuario,
                          v_cod_mod_padre,
                          v_cod_mad_padre,
                          v_cod_tra_padre,
                          user, ---cod_usu_reversion
                          v_hora,
                          'N', --Es nocturno.
                          'Reversion Fec. Valor');
  
        if pag_cta.g_cod_error <> 0 then
           r_gmovi.estado    := 'E';
           r_gmovi.cod_error := fug_obt_err_sueldos(pag_cta.g_cod_error, 'A');
        end if;
      else -- sólo actualiza la fecha
        update ge_movimientos
           set fec_valor = fecha
         where cod_usuario = reg.cod_usuario
           and fecha = reg.fecha
           and hora = reg.hora;
      end if;
   end loop;
exception
   when others then
     if sqlcode <= -20000 then
        raise;
     else
        raise_application_error(-20000,'Rev.Fec.Valor '||sqlerrm);
     end if;
END;
/

