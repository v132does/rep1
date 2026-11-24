CREATE OR REPLACE PROCEDURE IT.PRG_INI_ACR_IPS
 IS
   v_fec_actual ge_calendarios.fec_actual%type;
   v_error      varchar2(500);
   v_dir_para   varchar2(400);
   v_dir_de     varchar2(400);
BEGIN
   --BSEVOCORE-461 Habilita Acreditaciones IPS - PAG_IPS
   IF fug_obt_pardinamico('IPS_HAB_CON_INI') = 'S' then
     --Obtiene fecha del modulo general
     select fec_actual
     into v_fec_actual 
     from ge_calendarios
     where cod_modulo = 1;

     --- Actualizar fecha calendario de los demás modulos
     update ge_par_dinamicos
     set VAL_PARAMETRO = to_char(v_fec_actual,'dd/mm/yyyy')
     where PARAMETRO = 'IPS_ULT_FEC_INI';
   END IF;
EXCEPTION
      WHEN OTHERS THEN
         v_error     := substr(SQLERRM,1,500);
         IF fug_obt_pardinamico('IPS_HAB_CON_INI') = 'S' then
           v_dir_de    := fug_obt_dir_correo;
           v_dir_para  := fug_obt_pardinamico('IPS_ERR_NOT_MAILS');
           prg_ins_notificacion(sysdate,v_dir_de,v_dir_para,
               '[IPS] ERROR AL MODIFICAR FECHA DE INICIO DE ACREDITACIONES ',
               'Sin esta actualizacion las acreditaciones no se realizaran.' || chr(13) || chr(10) ||
               v_error || chr(13) || chr(10) ||
                'Para habilitar Acreditaciones: IPS_ULT_FEC_INI debe actualizarce con fec_actual de modulo 1 o '|| chr(13) || chr(10) ||
                ' Modificar IPS_HAB_CON_INI a valor N. ' ,
               'PRG_INI_ACR_IPS','NOTPROIPS');
          END IF;
         raise_application_error(-20000,'PRG_INI_ACR_IPS - ' || v_error);
END;
/

