CREATE OR REPLACE TRIGGER IT.TB_TA_SOLICITUDES
 BEFORE DELETE OR INSERT OR UPDATE
 ON "IT"."TA_SOLICITUDES"
 FOR EACH ROW
DECLARE
v_dir_cliente VARCHAR2(90);--ba_direcciones.direccion%type;
v_existe number;
v_error  varchar2(1000);
v_afinidad ta_tipos.afinidad%type;
v_existe_correo varchar2(1);
v_mensaje varchar2(200);
v_fecha date := pag_cal.FU_OBT_FEC_ACTUAL(5);
v_hora varchar2(10) := to_char(sysdate, 'hh24:mi:ss');
BEGIN
   if deleting then
      --- Eliminar historico de estados
      delete ta_sol_gestiones
       where nro_solicitud = :old.nro_solicitud;
   end if;
   if inserting then

     Begin -- Verificar que tenga direccion sea correcta para envio de extracto -- AAP 28-08-2007
       select substr( decode( e.tip_envio, 'D', d.direccion||decode(numero,null,'',' '||numero), -- Direccion
                                           'R', o.descripcion ), 1, 50 ) dir_envio
          into v_dir_cliente
          from ba_barrios b, ba_ciudades c, ba_paises p,
               ba_direcciones d, ge_dir_retenciones o, ge_dir_envios e
         where p.cod_pais(+) = d.cod_pais
           and c.cod_pais(+) = d.cod_pais
           and c.cod_ciudad(+) = d.cod_ciudad
           and b.cod_pais(+) = d.cod_pais
           and b.cod_ciudad(+) = d.cod_ciudad
           and b.cod_barrio(+) = d.cod_barrio
           and d.cod_persona(+) = e.cod_persona
           and d.cod_direccion(+) = e.referencia
           and o.cod_dir_retencion(+) = e.referencia
           and e.cod_persona = :new.cod_persona
           and e.nro_cuenta is null;
         if v_dir_cliente is null then
            RAISE no_data_found;
        end if;
      exception
       when no_data_found then
         if nvl(PAE_CNF.FU_OBT_COD_PROGRAMA,'x')!=nvl(fug_obt_pardinamico('NOM_PRO_ACT_TAR_CREDITO'),'z') then -- para que no de error cuando se activa desde la app
            raise_application_error(-20000,'Cliente no tiene definida una Dirección válida para el Envío del Extracto. ' ||
                                            'Verifique en la Carpeta de la Persona.');
         end if;
      end;

      --*
      --* Controles varios de personas
      --*
      v_error := fut_val_personas(:new.cod_persona,:new.cod_modulo,:new.cod_modalidad,
                                   :new.cod_moneda,:new.cod_oficina);
      if  v_error is not null then
         raise_application_error(-20000,v_error);
      end if;
      --*
      --* Controlar que si se marco como Debito Automatico que tenga la cuenta de debito
      --*
      if  :new.deb_automatico = 'S'
      and :new.nro_cta_debito is null then
        raise_application_error(-20000,'Debe ingresar la cuenta de Débito');
      End if;

      --*
      --* Controlar que la afinidad corresponda al tipo de Tarjeta
      --*
      if  :new.afinidad is null then   -- Si es nulo debe traer la afinidad definida en ta_tipos
         Begin
           select afinidad
             into v_afinidad
             from ta_tipos
            where cod_modalidad = :new.cod_modalidad
              and cod_modulo    = :new.cod_modulo
              and rownum = 1;

           :new.afinidad := v_afinidad;
         Exception
          when others then
             raise_application_error(-20000,'Error al traer afinidad en ta_tipos : '||sqlerrm);
         End;
      else
         Begin
          select 0 into v_Existe
           from  ta_tipos t
            where t.cod_modulo   = :NEW.cod_modulo
             and t.cod_modalidad = :NEW.cod_modalidad
             and t.afinidad      = :NEW.afinidad
              and substr(:NEW.afinidad,1,2) = t.cod_tip_tarjeta
              and rownum = 1;
         Exception
           When no_Data_found then
             raise_application_error(-20000,'La afinidad no corresponde al tipo de tarjeta.');
           When others then
             raise_application_error(-20000,'Error : '||sqlerrm);
         End;
      End if;
      --*
      --* Controlar que la Sub afinidad corresponda a la Afinidad
      --*
      if  :new.sub_afinidad is not null then
        Begin
          select 0 into v_Existe
            from  ba_cod_referencias r
            where r.dominio = 'SUB_AFINIDAD'
              and r.val_minimo    = :NEW.Sub_afinidad
              and r.val_maximo    = :NEW.afinidad;
        Exception
          When no_Data_found then
             raise_application_error(-20000,'La Sub afinidad no corresponde a la Afinidad.');
          When others then
             raise_application_error(-20000,'Error : '||sqlerrm);
        End;
      end if;
             --*
             --* Controlar que la persona no tenga ya una solicitud pendiente o aprobada con la misma modalidad,afinidad
             --*
      --*
      --* Controlar que la persona no tenga ya una solicitud pendiente o aprobada con la misma modalidad,afinidad
      --*
      if :new.cod_ent_procesadora<>fug_obt_pardinamico('COD_ENT_GLOBAL') then
        select count(*) into v_Existe
          from  ta_solicitudes
          where cod_persona     = :new.cod_persona
            and cod_modalidad   = :new.cod_modalidad
            and afinidad        = :new.afinidad
            and cod_estado      <> 'RCH' ;
          If v_existe <> 0 then
             raise_application_error(-20000,'La persona : '||:new.cod_persona||' ya posee solicitud activa para la modalidad y afinidad.');
          End if;
       end if;

      --
       select count(*) into v_Existe
        from  ta_cta_tarjetas c, ta_tarjetas t, ge_cta_clientes g
        where t.cod_persona   = :new.cod_persona
          and g.cod_persona   = :new.cod_persona
          and t.cod_estado <> 10
          and c.nro_cuenta    = t.nro_cuenta
          and c.nro_cuenta    = g.nro_cuenta
          and g.relacion      = 'P'
          and c.cod_modalidad  = :new.cod_modalidad
          and c.afinidad       = :new.afinidad
          and nvl(c.sub_afinidad,'ZZ') = nvl(:new.sub_afinidad,'ZZ');
        If v_existe <> 0 then
           raise_application_error(-20000,'La persona : '||:new.cod_persona||' ya posee tarjeta para la modalidad y afinidad.');
        End if;

        --- Controlar que la Persona no sea Adicional de la misma afinidad que se quiere solicitar

  /*       select count(*) into v_Existe
         from  ta_cta_tarjetas c, ta_tarjetas t, Ta_Sol_Adicionales s
         where t.cod_persona   = :new.cod_persona
          and  s.cod_persona = :new.cod_persona
          and  t.cod_persona   = s.cod_persona
          and t.cod_estado <> 10
          and (c.nro_cuenta    = t.nro_cuenta or s.nro_cuenta = :new.nro_cuenta)
          and c.nro_cuenta     = s.nro_cuenta
          and c.cod_modalidad  = :new.cod_modalidad
          and c.afinidad       = :new.afinidad
          and nvl(c.sub_afinidad,'ZZ') = nvl(:new.sub_afinidad,'ZZ')
          and s.cod_estado      in ('PAN','TIA','APR') ;

          If v_existe <> 0 then
             raise_application_error(-20000,'La persona : '||:new.cod_persona||' ya posee solicitud activa para la modalidad y afinidad.');
          End if;

      --
       select count(*) into v_Existe
        from  ta_cta_tarjetas c, ta_tarjetas t
        where t.cod_persona   = :new.cod_persona
          and t.cod_estado <> 10
          and c.nro_cuenta    = t.nro_cuenta
          and c.cod_modalidad  = :new.cod_modalidad
          and c.afinidad       = :new.afinidad
          and nvl(c.sub_afinidad,'ZZ') = nvl(:new.sub_afinidad,'ZZ');
        If v_existe <> 0 then
           raise_application_error(-20000,'La persona : '||:new.cod_persona||' ya posee tarjeta para la modalidad y afinidad.');
        End if;  */

       ---Controlar que tenga cargada una Direc de Email si elige Envío por Email
       if :new.env_email = 'S' then
        begin
          select 'S' into v_existe_correo
            from ba_personas
            where cod_persona = :new.cod_persona
            and dir_correo is not null
            ;
        exception
           when no_data_found then
             v_existe_correo := 'N';
        end;
          if nvl(v_existe_correo,'N') <> 'S' then
             raise_application_error(-20000,'Ingrese Dirección de Correo de la Persona :' ||:new.cod_persona );
          end if;
       end if;
       ---
        --*
  --* RI:10/09/2010: Controlar que la persona no se encuentre inhibido para solicitar tarjeta
  --*
  select count(*) into v_existe
    from ge_par_causales p, ge_causales c, ge_per_inhibidas i
   where i.cod_persona = :new.cod_persona
     and c.cod_causa   = i.cod_causa
     and p.cod_causa   = c.cod_causa
     and p.parametro   = 'AFE_TARJETAS'
     and i.estado ='I'
     and p.val_parametro = 'S';
  if  v_existe <> 0 then
    raise_application_error(-20000,'La persona : '||:new.cod_persona||' se encuentra inhibida para este tipo de cuenta.');
  end if;
   end if;
END;
/

