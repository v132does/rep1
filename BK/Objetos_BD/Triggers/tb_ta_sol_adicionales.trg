CREATE OR REPLACE TRIGGER IT.TB_TA_SOL_ADICIONALES
BEFORE INSERT
 ON TA_SOL_ADICIONALES
 FOR EACH ROW
DECLARE
v_existe number;
v_cod_modalidad ta_cta_tarjetas.cod_modalidad%type;
v_afinidad      ta_cta_tarjetas.afinidad%type;
v_sub_afinidad  ta_cta_tarjetas.sub_afinidad%type;
BEGIN
  If  :new.nro_solicitud is not null then
    Begin
      Select cod_modalidad, afinidad, sub_afinidad
        into v_cod_modalidad, v_afinidad, v_sub_afinidad
        from ta_solicitudes
       where nro_solicitud = :new.nro_solicitud;
    Exception
      when others then
        raise_application_error(-20000,'No encuentra la Solicitud del Titular. Nro.de Solicitud : '||:new.nro_solicitud);
    End;
  elsif :new.nro_cuenta is not null then
    Begin
      Select cod_modalidad, afinidad, sub_afinidad
        into v_cod_modalidad, v_afinidad, v_sub_afinidad
        from ta_cta_tarjetas
       where nro_cuenta = :new.nro_cuenta;
    Exception
      when others then
        raise_application_error(-20000,'No encuentra la Cuenta del Titular. Nro.de Cuenta : '||:new.nro_cuenta);
    End;
  End if;
  --*
  --* Controlar que la persona no tenga ya una solicitud pendiente o aprobada con la misma modalidad,afinidad
  --*
  if nvl(PAE_CNF.G_PROGRAMA,'x') IN('GMPROARC','GMARCHIV') then   --El control solo para Altas Masivas
      select count(*) into v_Existe
        from  ta_solicitudes
        where cod_persona     = :new.cod_persona
          and cod_modalidad   = v_cod_modalidad
          and afinidad        = v_afinidad
          and nvl(sub_afinidad,'ZZ') = nvl(v_sub_afinidad,'ZZ')
          and cod_estado      <> 'RCH' ;
      If v_existe <> 0 then
        raise_application_error(-20000,'La persona : '||:new.cod_persona||' ya posee solicitud activa para la modalidad y afinidad.');
      End if;
      --
      select count(*) into v_Existe
        from  ta_cta_tarjetas c, ta_tarjetas t
        where t.cod_persona   = :new.cod_persona
          and t.cod_estado <> 10
          and c.nro_cuenta    = t.nro_cuenta
          and c.cod_modalidad  = v_cod_modalidad
          and c.afinidad       = v_afinidad
          and nvl(c.sub_afinidad,'ZZ') = nvl(v_sub_afinidad,'ZZ');
      If v_existe <> 0 then
        raise_application_error(-20000,'La persona : '||:new.cod_persona||' ya posee tarjeta para la modalidad y afinidad.');
      End if;
   End if;

END;
/

