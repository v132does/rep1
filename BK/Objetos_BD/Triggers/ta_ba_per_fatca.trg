CREATE OR REPLACE TRIGGER IT.TA_BA_PER_FATCA
   AFTER DELETE OR INSERT OR UPDATE
   ON BA_PER_FATCA
   FOR EACH ROW

DECLARE
   v_env_mail       varchar2(1) := 'N';
   v_dir_cor_fatca  ge_par_dinamicos.val_parametro%type;
   v_dir_envio      ge_par_generales.dir_correo%type   := fug_obt_dir_correo;
BEGIN
   If updating Then
      
      If nvl(:old.estado,'X') != nvl(:new.estado,'X') Then
         --> Buscar Parametria de cambio de estado
         Begin
              select distinct(e.ind_env_mail)
                into v_env_mail
                from ge_par_fatca c, ge_est_fatca e
               where c.est_nuevo    = e.est_fatca
                 and c.est_nuevo    = :new.estado;
         Exception
               When no_data_found Then
                    v_env_mail := 'N';
               when too_many_rows then
                    v_env_mail := 'N';
                    raise_application_error(-20000,'Exite más de una configuración para el cambio de estado');
               When others Then
                    v_env_mail := 'N';
                    raise_application_error(-20000,'Error buscando configuración de envío de correo '||sqlerrm);
         End;
         --> Si V_ENV_MAIL = 'S', buscar dirección de correo
         If nvl(v_env_mail,'N') = 'S' Then
            v_dir_cor_fatca  := fug_obt_pardinamico('DIR_COR_FATCA');
         End If;
         
         If nvl(v_env_mail,'N') = 'S' and v_dir_cor_fatca is not null Then
            prg_env_mail(v_dir_envio       ,
                         v_dir_cor_fatca   ,
                         'Persona en FATCA',
                         'Se ha realizado la siguiente actualización para la persona: '||
                         :new.cod_persona||' '||fue_obt_nom_persona(:new.cod_persona)  ||chr(10)||
                         'Estado Anterior: '||pae_fat.FU_OBT_DES_ESTADO(:old.estado) ||chr(10)||
                         'Estado Nuevo: '   ||pae_fat.FU_OBT_DES_ESTADO(:new.estado) ||chr(10)||
                         'Atentamente.');
         End If;  
      End If;

   End If;
   
EXCEPTION
   WHEN OTHERS THEN
        raise_application_error(-20000,'Error. TA_BA_PER_FATCA'||sqlerrm);
END;
/

