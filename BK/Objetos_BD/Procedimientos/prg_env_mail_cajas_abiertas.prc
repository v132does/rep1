CREATE OR REPLACE PROCEDURE IT.PRG_ENV_MAIL_CAJAS_ABIERTAS IS
  /*
  Solicitud nro 77 ID389 Estado de cajas
  Autor: Pablo Ruiz Diaz | Simgia
  Basado en codigo proveido por Gabriel Capo
  
  Descripcion de funcion: Consulta cuales son las cajas abiertas al momento de la ejecucion del procedimiento,
  y envia un mail a los cajeros asociados, asi como a su JGO. Pidiendo en el mail que indique el motivo  y tiempo
  estimado de cierre.
  Si no se cuenta con el mail del JGO en la base de datos, se enviara a un responsable de sistema indicado en el procedimiento.
  */
  V_DIR_CORREO_SAN           VARCHAR2(100) := fug_obt_pardinamico('CAM_MAR_DIR_SANTI');
  V_DIR_CORREO_DE            VARCHAR2(100) := fug_obt_pardinamico('CAM_MAR_DIR_MAI_NET');--'BBVAnet@bbva.com.py';
  V_DIR_CORREO_PARA          VARCHAR2(5000) := V_DIR_CORREO_SAN;--'svillanueva@bbva.com.py';
  v_dir_correo_resp_sistemas varchar2(300) := V_DIR_CORREO_SAN;--'svillanueva@bbva.com.py'; --cargar aqui direccion de responsable de sistemas
  v_fec_actual               date := TRUNC(pae_cnf.FU_OBT_FEC_ACTUAL(1));
  v_dir_correo_jgo           varchar2(300);

  v_detalle        VARCHAR2(3000);
  v_cabecera       VARCHAR2(3000);
  v_fin            VARCHAR2(3000);
  v_cod_ofi_actual varchar(100);
  -- cursor que lista cajas no cerradas
  CURSOR c_cajas IS
    SELECT distinct (a.nro_caja),
                    decode(b.estado,
                           1,
                           'Abierto',
                           2,
                           'Cerrado',
                           3,
                           'Reabierto',
                           4,
                           'Arqueado') Estado_Caja,
                    a.cod_oficina,
                    d.cod_usu_encargado,
                    e.nombre as nombre_jgo,
                    c.nombre as nombre_cajero,
                    case
                      when c.dir_correo is null then
                       V_DIR_CORREO_SAN
                      else
                       c.dir_correo
                    end correo_cajero,
                    case
                      when e.dir_correo is null then
                       V_DIR_CORREO_SAN
                      else
                       e.dir_correo
                    end correo_jgo,
                    b.fecha,
                    d.descripcion des_oficina
      FROM cj_cajas     a,
           cj_controles b,
           ba_usuarios  c,
           ba_oficinas  d,
           ba_usuarios  e
     WHERE a.nro_caja = b.nro_caja
       AND b.estado <> 2
       AND a.cod_usuario = c.cod_usuario
       AND d.cod_oficina = a.cod_oficina
       AND e.cod_usuario = d.cod_usu_encargado
       and b.FECHA = v_fec_actual
     ORDER by a.cod_oficina ASC;

BEGIN
  V_DIR_CORREO_PARA := '';

  v_cod_ofi_actual := -1; --bandera, para actualizar luego al codigo de oficina e indicar que es la primera vez que se ejecuta
  v_fin            := '</table><br/><br/><p>Atentamente, </p> <img src='|| fug_obt_pardinamico('URL_BCO_LOGO')||'" alt="Site Logo"  /></p>
                            </body>
                          </html>';

  FOR registro IN c_cajas LOOP
    if (v_cod_ofi_actual <> registro.cod_oficina) then
      if (v_cod_ofi_actual <> -1) then
        --si no es la primera vez del corte de control, entonces enviar el mail
        PRG_SEND_MAIL(p_to        => V_DIR_CORREO_PARA,
                      p_from      => V_DIR_CORREO_DE,
                      p_subject   => 'Cierres de Cajas y Confirmación de Operaciones ' ||
                                     v_fec_actual,
                      p_text_msg  => '',
                      p_html_msg  => V_CABECERA || V_DETALLE || V_FIN ,
                      p_smtp_host => fug_obt_pardinamico('DIR_SER_CORREOS'),
                      p_smtp_port => 25,
                      pcc         => v_dir_correo_jgo);
        v_dir_correo_para := '';
      end if;
      V_COD_OFI_ACTUAL := registro.cod_oficina;
      -- correo de jgo por defecto, alguien de sistemas;
      v_dir_correo_jgo := v_dir_correo_resp_sistemas;
      if (registro.correo_jgo is not null) then
        --si hay JGO entonces ponemos su direccion de mail
        v_dir_correo_jgo := registro.correo_jgo;
      end if;
      v_cabecera := '<html><body><p>Seguido se expone el detalle de Cajas de la Oficina de la<b> ' || registro.des_oficina || '</b>
      que al momento siguen pendientes de Cierre Diario de sus operaciones, y en tal sentido se requiere al JGO de la Oficina, responder el presente a la dirección de correo ' ||
      v_dir_correo_resp_sistemas  || ' con debida explicación del motivo de retraso y/o tiempo estimado de cierre, para cada una de las Cajas afectadas:<p> 
      <table width="100%"><tr><td width="30%">Detalle de Cajas</td><td width="30%">Comentario del JGO</td><td width="30%">Horario estimado de Cierre</td></tr>';
    
      v_detalle := ''; --reinicializamos detalle
    end if;
    -- recoleccion de destinatarios del mail
    if ((case when v_dir_correo_para is null then 0 else
        length(v_dir_correo_para) end) = 0) then
      --si es el primero no lleva coma
      V_DIR_CORREO_PARA := registro.correo_cajero;
    else
      V_DIR_CORREO_PARA := registro.correo_cajero;
    end if;
    -- detalle del mensaje
    v_detalle := v_detalle || '<tr><td>Caja Nro: ' || registro.nro_caja ||
                 '</td><td> * </td><td>HH:MM</td></tr>';
  
    EXIT WHEN c_cajas%NOTFOUND;
  
  END LOOP;

  if (length(v_detalle) > 1) then
    -- quiere decir que quedaron detalles por enviar, enviamos los restantes
    PRG_SEND_MAIL(p_to        =>  V_DIR_CORREO_PARA,
                  p_from      => V_DIR_CORREO_DE,
                  p_subject   => 'Cierres de Cajas y Confirmación de Operaciones ' ||
                                 v_fec_actual,
                  p_text_msg  => '',
                  p_html_msg  => V_CABECERA || V_DETALLE || V_FIN,
                  p_smtp_host => fug_obt_pardinamico('DIR_SER_CORREOS'),
                  p_smtp_port => 25,
                  pcc         => v_dir_correo_jgo);
  
  end if;

end;
/

