CREATE OR REPLACE TRIGGER IT.tb_ge_paq_cuentas
 before delete or insert or update
  on ge_paq_cuentas
 for each row
declare
  v_cod_modulo number(3);
  v_cod_modalidad number(3);
  v_cod_sub_modalidad number(3);
  v_afinidad ta_tipos.afinidad%type;
  v_sub_afinidad ta_tipos.sub_afinidad%type;
begin

  if inserting then
      --Traer Módulo y Modalidad
      select z.cod_modulo, z.cod_modalidad
        into v_cod_modulo, v_cod_modalidad
        from ge_cuentas z
       where z.nro_cuenta = :new.nro_cuenta;

      --Asignar Valores a los Campos
      :new.cod_modulo    := v_cod_modulo;
      :new.cod_modalidad := v_cod_modalidad;

      begin
        --Traer Sub Modalidad o Sub Afinidad
        if v_cod_modulo != 5 then
          select cod_sub_modalidad, afinidad, sub_afinidad
            into v_cod_sub_modalidad, v_afinidad, v_sub_afinidad
            from ge_paq_modalidades
           where cod_paquete = :new.cod_paquete
             and cod_modulo = :new.cod_modulo
             and cod_modalidad = :new.cod_modalidad;
        else
           select z.afinidad
             into v_afinidad
             from ta_cta_tarjetas z
            where z.nro_cuenta=  :new.nro_cuenta;
            
            select cod_sub_modalidad, sub_afinidad
              into v_cod_sub_modalidad, v_sub_afinidad
              from ge_paq_modalidades
             where cod_paquete = :new.cod_paquete
               and cod_modulo = :new.cod_modulo
               and cod_modalidad = :new.cod_modalidad
               and afinidad = v_afinidad;
        end if;
       exception
         when no_data_found then
            raise_application_error(-20000,'TB_GE_PAQ_CUENTAS - Modalidad no Vinculada a Este Paquete ');
       end;
       
      :new.afinidad := v_afinidad;
      :new.sub_afinidad := v_sub_afinidad;
      :new.cod_sub_modalidad := v_cod_sub_modalidad;

      --Actualizar Sub-Modalidades de las Cuentas
      if v_cod_modulo = 3 then
         update ah_cta_vistas a set a.cod_sub_modalidad=v_cod_sub_modalidad where a.nro_cuenta=:new.nro_cuenta;
      elsif v_cod_modulo = 4 then
         update cc_cta_corrientes c set c.cod_sub_modalidad=v_cod_sub_modalidad where c.nro_cuenta=:new.nro_cuenta;
      elsif v_cod_modulo = 5 then
         update ta_cta_tarjetas t set t.sub_afinidad = v_sub_afinidad where t.nro_cuenta=:new.nro_cuenta;
      end if;

  elsif deleting then
  
      --Traer Módulo y Modalidad
      select z.cod_modulo, z.cod_modalidad
        into v_cod_modulo, v_cod_modalidad
        from ge_cuentas z
       where z.nro_cuenta = :old.nro_cuenta;  
  
      --Actualizar Sub-Modalidades de las Cuentas
      if v_cod_modulo = 3 then
         update ah_cta_vistas a set a.cod_sub_modalidad=1 where a.nro_cuenta=:old.nro_cuenta;
      elsif v_cod_modulo = 4 then
         update cc_cta_corrientes c set c.cod_sub_modalidad=1 where c.nro_cuenta=:old.nro_cuenta;        
      elsif v_cod_modulo = 5 then
         /*
         || RABF-23/05/2013: En la afinidad de la tarjeta,
         || la referencia Normal corresponde al valor maximo
         || de la afinidad de la tarjeta despaquetizada
         */
         Begin
           SELECT nvl(val_maximo,'ZZ')
             INTO v_sub_afinidad
             FROM ba_cod_referencias
            WHERE dominio = 'AFINIDAD'
              AND val_minimo = :old.afinidad;	  
         Exception
           when others then
               v_sub_afinidad := null;
         End;
         update ta_cta_tarjetas t set t.sub_afinidad = decode(v_sub_afinidad,'ZZ',null,v_sub_afinidad) where t.nro_cuenta=:old.nro_cuenta;       
      end if;
      
  end if;
 exception
  when others then
   raise_application_error(-20000,'TB_GE_PAQ_CUENTAS -'||sqlerrm||'Cuenta Nro. '||:new.nro_cuenta);
end tb_ge_paq_cuentas;
/

