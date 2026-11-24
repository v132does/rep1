CREATE OR REPLACE TRIGGER IT.tb_ge_paq_clientes
 after delete or insert or update
  on ge_paq_clientes
 for each row
declare
 v_sub_afinidad ta_cta_tarjetas.sub_afinidad%type;
begin

   if updating then
      --Se esta Cancelando el Paquete
      if :old.estado = 'N' and :new.estado = 'C' then

         for k in (select t.*,t.rowid registro
                     from ge_paq_cuentas t
                    where t.cod_paquete = :new.cod_paquete
                      and t.cod_persona = :new.cod_persona
                      and t.nro_secuencia = :new.nro_secuencia) loop

            --Actualizar Sub-Modalidades de las Cuentas
            if k.cod_modulo = 3 then
               update ah_cta_vistas a set a.cod_sub_modalidad = 1 where a.nro_cuenta=k.nro_cuenta;
            elsif k.cod_modulo = 4 then
               update cc_cta_corrientes c set c.cod_sub_modalidad = 1 where c.nro_cuenta=k.nro_cuenta;
            elsif k.cod_modulo = 5 then
               /*RI : 22/04/2010 : Se debe asignar la sub afinidad normal que corresponde al menor
                 valor de sub afinidad para la afinidad  */
               Begin 
                 select min(nvl(t.sub_afinidad,'ZZ')) 
                   into v_sub_afinidad
                   from ta_cta_tarjetas c, ta_tipos t
                  where t.cod_modulo = c.cod_modulo
                    and t.cod_modalidad = c.cod_modalidad
                    and t.afinidad   = c.afinidad
                    and c.nro_cuenta = k.nro_cuenta;
               Exception
                 when others then
                     v_sub_afinidad := null;
               End;            
               update ta_cta_tarjetas t set t.sub_afinidad = decode(v_sub_afinidad,'ZZ',null,v_sub_afinidad) where t.nro_cuenta=k.nro_cuenta;             
            end if;

         end loop;
         
         --Eliminar las Cuentas del Detalle del Paquete
         delete from ge_paq_cuentas x 
          where x.cod_paquete = :new.cod_paquete
            and x.cod_persona = :new.cod_persona
            and x.nro_secuencia = :new.nro_secuencia;

      end if;
   end if;
 exception
  when others then
   raise_application_error(-20000,'TB_GE_PAQ_CLIENTES -'||sqlerrm);
end tb_ge_paq_clientes;
/

