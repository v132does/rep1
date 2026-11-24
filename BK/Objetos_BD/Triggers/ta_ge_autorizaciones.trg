CREATE OR REPLACE TRIGGER IT.TA_GE_AUTORIZACIONES
 AFTER DELETE OR INSERT OR UPDATE
 ON GE_AUTORIZACIONES
 FOR EACH ROW
DECLARE
   v_mto_a_cobrar ge_exoneraciones_tmp.mto_a_cobrar%type;
begin
   if updating then
      if :new.cod_usu_utilizador <> nvl(:old.cod_usu_utilizador,'x')
      and :new.cod_usuario is not null and :new.nro_secuencia is not null then
         --- Actualizar estado del movimiento
         update ge_movimientos
            set estado = 'N'
          where estado = 'X'
            and cod_usuario = :new.cod_usuario
            and fecha = :new.fecha
            and hora = :new.hora
            and nro_secuencia = :new.nro_secuencia;
	/*         if sql%notfound then
            raise_application_error(-20000,
            'Movimiento utilizado no pudo actualizarse');
         end if;*/
      end if;
      --- PCC-Exoneración y Extorno de Comisiones y Tasas
      if nvl(:new.cod_modulo, nvl(:old.cod_modulo, 1)) in (6,15) and
         nvl(:new.valor, nvl(:old.valor, 0)) <> 0 and
         :new.cod_usu_utilizador is not null and
         :new.fec_utilizacion is not null and
         :new.hor_utilizacion is not null and
         :old.nro_cuenta is not null then
         begin
            select a.mto_a_cobrar
              into v_mto_a_cobrar
              from ge_exoneraciones_tmp a
             where a.nro_pedido = :old.cod_autorizacion;
         exception
            when no_data_found then
               v_mto_a_cobrar := null;
         end;
         prg_ins_exoneracion(:old.cod_transaccion,:old.cod_modulo,:old.cod_modalidad,
                             nvl(:old.cod_moneda,fug_obt_mon_cta(:old.nro_cuenta)),
                             :old.nro_cuenta,null,null,
                             nvl(:new.valor, nvl(:old.valor, 0)),--mto_exonerado
                             nvl(v_mto_a_cobrar,0),--mto_a_cobrar
                             nvl(:old.cod_usuario,:old.usu_insercion),
                             nvl(:new.valor, nvl(:old.valor, 0)),--mto_no_cob
                             :old.cod_autorizacion, -- BSEVOCORE-40 2019/10 NAF
                             :new.fec_utilizacion,
                             :new.hor_utilizacion,
                             :new.cod_usu_utilizador);
         update ge_exoneraciones_tmp
            set estado = 'A'
          where nro_pedido = :old.cod_autorizacion;
      end if;
   end if;
end TA_GE_AUTORIZACIONES;
/

