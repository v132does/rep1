CREATE OR REPLACE PROCEDURE IT.PRB_REG_MAIL(p_cod_persona           IN ba_personas.cod_persona%type,
                                            p_tip_persona           IN ba_personas.tipo%type,
                                            p_tip_producto          IN ba_env_emp_correos.tip_producto%type,
                                            p_parametros            IN long,
                                            p_destinatarios         IN ba_env_emp_correos.destinatarios%type,
                                            p_firmantes             IN VARCHAR2,
                                            p_cod_error             OUT VARCHAR2,
                                            p_mensaje               OUT VARCHAR2) IS
  v_retorn varchar2(2000);
  v_retorn2 varchar2(2000);
  v_correo varchar2(2000);
  v_cod_persona varchar2(2000);
  v_destinatarios varchar2(2000);
  v_nro_correo number;
BEGIN
   begin pre_ini_aplicacion;
      pae_cnf.g_cod_modulo := 1;
   end;
    -- Validar tipo de persona
    if p_tip_persona is null then
         p_cod_error := '1011';
         p_mensaje := 'Tipo de persona se encuentra vacio.';
    end if;
    -- Validar obligatorio mail para personas Juridicas/Fisicas
   if p_destinatarios is null and p_tip_persona = 'J' then
         p_cod_error := '1012';
         p_mensaje := 'La persona Juridica debe poseer un correo.';
    elsif p_destinatarios is null and p_tip_persona = 'F' then
         p_cod_error := '1013';
         p_mensaje := 'La persona Fisica debe poseer un correo.';
    end if;
  if p_firmantes is not null then
    -- Recupera los codigo de persona
    begin
      v_retorn2 := q'[ select listagg(''''||ba.cod_persona||'''',',')
                within group(order by ba.cod_persona) cod_persona
      from ba_personas ba
      where ba.nro_documento in (]' || p_firmantes ||')';
     -- Guarda en una variable los codigo de persona --
      EXECUTE IMMEDIATE v_retorn2 INTO v_cod_persona;
    end;
    -- Sql dinamico recupera los correos concatenados
    begin
       v_retorn := q'[select listagg(''''||a.val_parametro||'''',',')
             within group(order by a.val_parametro) val_parametro
      from ba_tab_dat_adicionales a
      where parametro = 'EMAIL_ONBOARDING'
      and referencia in (]' || v_cod_persona ||')';
    -- Guarda en una variable los correos concatenados --
      EXECUTE IMMEDIATE v_retorn INTO v_correo;
    end;
  end if;
    -- Concatenacion de los correos
    if p_destinatarios is not null and v_correo is not null then
       v_destinatarios := p_destinatarios ||','||v_correo;
    elsif p_destinatarios is not null and v_correo is null then
       v_destinatarios := p_destinatarios;
    else
       v_destinatarios := v_correo;
    end if;
    -- Generacion nro_correo --
     begin
          select nvl(max(b.nro_correo),0) + 1
          into v_nro_correo
          from ba_env_emp_correos b;
      exception
        when others then
          p_cod_error := '1014';
          p_mensaje := 'Error al obtener el numero de correo. '||sqlerrm;
      end;
   -- Inserccion deacuerdo al Tipo de Persona --
 if p_cod_error is null then
    if p_tip_persona = 'J' then
       insert into ba_env_emp_correos(nro_correo,cod_persona,tip_producto,estado,fec_registro,fec_envio,msj_error, parametros, destinatarios)
       values(v_nro_correo, p_cod_persona,p_tip_producto,'P',sysdate,NULL,NULL,p_parametros,v_destinatarios);
     end if;

     if p_tip_persona = 'F' then
        insert into ba_env_correos (nro_correo, cod_persona, tip_producto, estado, fec_registro,fec_envio, msj_error,parametros, mai_destinatario)
        values(v_nro_correo,p_cod_persona, p_tip_producto, 'P',sysdate, null,null,p_parametros,p_destinatarios);
      end if;
    commit;
 end if;
EXCEPTION
    WHEN OTHERS THEN
        p_cod_error := '1015';
        p_mensaje := 'Ocurrio inesperado durante la ejecucion. '||sqlerrm;
END;
/

