create or replace procedure it.PRG_INS_ONB_PERSONAS( p_nro_documento in ba_personas.nro_documento%type,
                                                    p_telefono in ba_telefonos.telefono%type,
                                                    p_correo in ba_personas.dir_correo%type,
                                                    p_direccion in ba_onb_personas.direccion%type,
                                                    p_nro_casa in ba_onb_personas.nro_casa%type,
                                                    p_cod_dpto in ba_onb_personas.cod_dpto%type,
                                                    p_cod_ciudad in ba_onb_personas.cod_ciudad%type,
                                                    p_cod_barrio in ba_onb_personas.cod_barrio%type,
                                                    p_cod_ocupacion in ba_onb_personas.cod_ocupacion%type,
                                                    p_cod_pais in ba_onb_personas.cod_pais%type,
                                                    p_cod_error out number,
                                                    p_men_error out varchar2,
                                                    p_cod_persona out varchar2 ) is

v_existe         varchar2(1);
v_cod_onb_per    ba_personas.cod_persona%type;
v_dir_mail       ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('MAI_ONB_PERSONAS');
v_asunto         varchar2(100);
v_txt_mail       varchar2(1000);
v_remitente      ge_par_generales.dir_correo%type;
v_pro_correcto   number := 200;
v_err_sql        number := nvl(fug_obt_pardinamico('COD_ERR_SQL'), '999');
v_des_pais       ba_paises.descripcion%type;
v_des_ciudad     ba_ciudades.descripcion%type;
v_des_barrio     ba_barrios.descripcion%type;
v_des_dpto       ba_departamentos.descripcion%type;
v_des_ocupacion  ge_rub_economicos.descripcion%type;
v_nro_casa       varchar2(10);
v_rub_primario   ge_rub_economicos.cod_rub_economico%type;
begin
  Begin PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO := 1; End;
  --Validamos si existe la persona previamente registrada
  p_cod_error := v_pro_correcto;
  Begin
    Select 'S'
      into v_existe
      from ba_onb_personas
     where nro_documento = p_nro_documento;
  Exception
    when no_data_found then
      v_existe := 'N';
  End;
  p_cod_persona := -1;
  If v_existe = 'N' then
  --Si no existe en la tabla se inserta el registro
  Begin
    Select s_cod_onb_per.nextval into v_cod_onb_per from dual;
    Insert into ba_onb_personas
      (cod_onb_per,
       nro_documento,
       telefono,
       email,
       direccion,
       nro_casa,
       cod_dpto,
       cod_ciudad,
       cod_barrio,
       cod_ocupacion,
       estado,
       cod_persona,
       cod_pais)
    values
      (v_cod_onb_per,
       p_nro_documento,
       p_telefono,
       p_correo,
       p_direccion,
       p_nro_casa,
       p_cod_dpto,
       p_cod_ciudad,
       p_cod_barrio,
       p_cod_ocupacion,
       null,
       null,
       p_cod_pais);

     Exception
       when others then
         p_cod_error := v_err_sql;
         p_men_error := 'Ocurrio un error al crear Persona ' || sqlerrm ;
         prg_ins_log_programas('PR_INS_ONB_PERSONAS', 'Nro.Documento: '
                               || p_nro_documento || '. Error: ' || p_men_error, v_cod_onb_per, null);
      End;

      --Si se inserta correctamente envio mail
      If p_cod_error = v_pro_correcto then
        if p_nro_casa is not null then
          v_nro_casa := p_nro_casa;
        else
          v_nro_casa := 'N/A';
        end if;
        if p_cod_pais is not null then
          v_des_pais := fue_obt_des_pais(p_cod_pais);
        else
          v_des_pais := 'No ingresado';
        end if;
        if p_cod_dpto is not null then
          v_des_dpto := fue_obt_des_departamento(p_cod_dpto);
        else
          v_des_dpto := 'No ingresado';
        end if;
        if p_cod_ciudad is not null then
          v_des_ciudad := fue_obt_des_ciudad(p_cod_pais, p_cod_ciudad);
        else
          v_des_ciudad := 'No ingresado';
        end if;
        if p_cod_barrio is not null then
          v_des_barrio := fue_obt_des_barrio(p_cod_pais, p_cod_ciudad, p_cod_barrio);
        else
          v_des_barrio := 'No ingresado';
        end if;
        ----
        begin
        SELECT cod_rub_economico
          INTO v_rub_primario
          FROM ge_rub_economicos e
         WHERE cod_rub_economico =
               (select val_maximo
                  from ba_cod_referencias T
                 where t.dominio = 'ONB_OCUPACIONES'
                   and t.val_minimo = p_cod_ocupacion);
        exception
          when others then
            v_rub_primario := null;
        end;
        ----
        if v_rub_primario is not null then
          v_des_ocupacion := fug_obt_des_actividad(v_rub_primario, 'N');
        else
          v_des_ocupacion := 'No ingresado';
        end if;
        Begin
          If nvl(v_dir_mail, 'X') <> 'X' then
            ---v_dir_mail  :=;
            v_remitente := fug_obt_dir_correo;
            v_asunto    := 'Onboarding no exitoso - No se obtuvieron datos';
            v_txt_mail  := 'Cod. Persona Onboarding: ' || v_cod_onb_per ||
                           chr(10) || 'Nro. Documento: ' || p_nro_documento ||
                           chr(10) || 'Telefono: ' || p_telefono ||
                           chr(10) || 'Dir. Correo: ' || p_correo ||
                           chr(10);
            it_mail.mail(v_remitente, -- quien envia
                         v_dir_mail, -- a quien
                         v_asunto, -- asunto
                         v_txt_mail); -- detalle
          end if;
        exception
        when others then
          p_cod_error := v_err_sql;
          p_men_error := 'Persona ingresada. No se puedo enviar el mail de notificacion! ' || sqlerrm;
          prg_ins_log_programas('PR_INS_ONB_PERSONAS', 'Nro.Documento: '
                               || p_nro_documento || '. Error: ' || p_men_error, v_cod_onb_per, null);
        end;
      End if;

  Elsif v_existe = 'S' then
    p_cod_persona := -1;
  End if;
  If p_cod_error = v_pro_correcto then
    p_men_error := 'Registro ingresado con exito!';
  End if;

end PRG_INS_ONB_PERSONAS;
/

