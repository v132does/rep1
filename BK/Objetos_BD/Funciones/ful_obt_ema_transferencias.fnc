create or replace function it.ful_obt_ema_transferencias(p_cod_persona in varchar2, p_cod_oficina in number, p_cod_modalidad in number default null)
                                                         return varchar2 is

--Variables--
Result varchar2(4000);
v_contador number(2);
v_dir_com_exterior ge_par_entes.val_parametro%type := fug_obt_pardinamico('DIR_COR_COM_EXTERIOR');
v_rol_asistentes ba_usu_roles.cod_rol%type := fug_obt_pardinamico('ROL_USU_ASISTENTES');
--Cursores--
cursor c_dir_correo is
 --Correos asociados al Cliente para Transferencias--
 select a.dir_email
   from lc_dir_ema_clientes a
  where a.cod_persona = p_cod_persona
    and a.dir_email is not null
 --Se envia tambien al oficial del cliente--
 union all
 select fug_obt_dir_mail_usu(x.cod_usu_oficial)
   from ge_clientes x
  where x.cod_persona = p_cod_persona
    and fug_obt_dir_mail_usu(x.cod_usu_oficial) is not null
 --Se envia una copia al asistente de la sucursal--
 union all
 select fug_obt_dir_mail_usu(a.cod_usuario)
   from ba_usu_roles a, ba_usuarios x
  where a.cod_rol = v_rol_asistentes
    and a.cod_usuario = x.cod_usuario
    and x.cod_oficina = p_cod_oficina
    and fug_obt_dir_mail_usu(a.cod_usuario) is not null
    and nvl(p_cod_modalidad,999) = 72 --Solo en Transferencias Emitidas--
 --Se envia una copia a Comercio Exterior--
 union all
 select v_dir_com_exterior
   from dual;
begin
  v_contador := 0;
  for dir in c_dir_correo loop
      v_contador := v_contador + 1;
      if v_contador = 1 then
         result := dir.dir_email;
      else
         result := result||';'||dir.dir_email;
      end if;
  end loop;
  if result is not null then
     result := result||';';
  end if;
  return(Result);
end ful_obt_ema_transferencias;
/

