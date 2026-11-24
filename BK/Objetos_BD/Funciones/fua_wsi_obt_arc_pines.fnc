CREATE OR REPLACE FUNCTION IT.FUA_WSI_OBT_ARC_PINES (p_cod_procesadora varchar2)
 RETURN varchar2 IS
/* Autor:     Sergio Alejandro Servín Arce
   Propuesta: Función para obtener pines encriptados del Servidor FTP Bancarda, por medio de Webservice BancadConector
   Fecha:     31/08/2015

   OBS: Cargar v_con_error := 'SI*' para los errores que si o si se tienen que realizar ROLLBACK*/

 v_respuesta TYP_POSTRESPUESTACLOB;
 g_url_obt_pines       ge_par_dinamicos.val_parametro%TYPE := fug_obt_pardinamico('WSI_OBT_PINES');
 v_dir_ftp   ge_par_dinamicos.val_parametro%TYPE := fug_obt_pardinamico('SVR_FTP_BANCARD'); --contiene también el nombre del archivo
 v_direccion     varchar2(900) := '{"data":"' || v_dir_ftp || '"}';
 v_metodo    VARCHAR2(5) := 'POST';

 v_result varchar2(4000);

 v_con_error varchar2(3):= 'NO';
 v_cant_pines number:=0;
 v_hay_datos varchar2(1):='N';
 --función interna para la validación de cuentas, se agrega el parametro p_nro_bin para obtener el numero de cuenta real
   function LF_VAL_CTA_INFONET
     (p_nro_cuenta in varchar2,
      p_nro_bin    in varchar2)
      return varchar2 is

    /* función que recibe el nro de cuenta de infonet y verifica que exista en la base
    Busca en el formato recibido y si no encuentra busca con el cero inicial
    esto aplica sólo a ctas vistas */

    v_nro_cuenta  ge_cuentas.nro_cuenta%type;
    v_cuenta      ge_cuentas.nro_cuenta%type;
    v_cuenta_num  number := to_number(p_nro_cuenta);
    v_exi_cta     number;
    BEGIN
     --- Verificar si la cuenta de debito existe en Ge_cuentas, si no existe se presume es una cuenta
     --- que esta viniendo en el formato del banco, convertir al formato IT
     Select count(*) into v_exi_cta
      from ge_cuentas
     where nro_cuenta = p_nro_cuenta
       and cod_modulo in (3,4);
     if v_Exi_cta = 0 then   -- no existe, entonces convertir
       v_cuenta := lpad(substr(v_cuenta_num,1,length(v_cuenta_num)-7 ),2,'0')|| --Sucursal
                   case when substr(v_cuenta_num,length(v_cuenta_num) - 6,1) in ('1', '3') then '01'
                   when substr(v_cuenta_num,length(v_cuenta_num) - 6,1) in ('2', '4') then '02' end|| --Tipo
                   substr(v_cuenta_num,-6);
      else
       v_cuenta := p_nro_cuenta;
      end if;
    --
     Begin
      Select nro_cuenta
        into v_nro_cuenta
        from ge_cuentas
       where nro_cuenta = v_cuenta
       and cod_modulo in (3,4);
       return v_nro_cuenta;
    exception
       when no_data_found then
         -- buscamos en la tabla alias
         begin
		   -- SDBIN8TDD-1 se agrega la funcion fua_obt_cta_cliente para obtener el numero de cuenta real del cliente.
           v_nro_cuenta := fua_obt_cta_cliente(to_number(p_nro_cuenta), p_nro_bin);
           --  
           if v_nro_cuenta is not null then
              return v_nro_cuenta;
           else    
              --retorna la cuenta con notación itgf
             return v_cuenta;
           end if;  
           --
         exception
           when no_data_found then
             --retorna la cuenta con notación itgf
             return v_cuenta;
         end;
       when others then
          raise_application_error(-20000,'Error al validar cuenta:  '||p_nro_cuenta||'-'||sqlerrm);
     end;
    END;

--Procedimiento interno para manejo de caracteres especiales1
   procedure lp_pro_car_especiale(p_dato in out varchar2)
   is
     v_dato varchar2(400);
     v_cantLetras number;
     v_letra varchar2(1);
     v_pos_lnp varchar2(50);--pos de letras no permitidas
     v_pos_lnp2 varchar2(50); --pos de letras no permitidas
     v_dato_correcto varchar2(100);
     v_cont          number := 0;

      cursor car_np is
       SELECT token pos, rownum fila
         FROM (SELECT TRIM(SUBSTR(txt,
                                  INSTR(txt, '.', 1, level) + 1,
                                  INSTR(txt, '.', 1, level + 1) -
                                  INSTR(txt, '.', 1, level) - 1)) AS token
                 FROM (SELECT v_pos_lnp AS txt FROM dual)
               CONNECT BY level <=
                          LENGTH(txt) - LENGTH(REPLACE(txt, '.', '')) - 1);

      cursor car_np2 is
       SELECT token pos, rownum fila
         FROM (SELECT TRIM(SUBSTR(txt,
                                  INSTR(txt, ',', 1, level) + 1,
                                  INSTR(txt, ',', 1, level + 1) -
                                  INSTR(txt, ',', 1, level) - 1)) AS token
                 FROM (SELECT v_pos_lnp2 AS txt FROM dual)
               CONNECT BY level <=
                          LENGTH(txt) - LENGTH(REPLACE(txt, ',', '')) - 1);

     begin
      v_dato := p_dato;
      v_cantLetras := length(v_dato);

      for i in 1..v_cantLetras loop
         v_letra := substr(v_dato,i,1);

         if v_letra not in ('0','1','2','3','4','5','6','7','8','9',
                            'A','B','C','D','E','F','G','H','I','J',
                            'K','L','LL','M','N','O','P','Q','R','S',
                            'T','U','V','W','X','Y','Z',' ','.') THEN

            v_pos_lnp := v_pos_lnp||i||',';
            v_cont := v_cont + 1;
            if mod(v_cont, 2) = 0 then--Cuando es par se agrupa
             v_pos_lnp := v_pos_lnp || '.,';
            end if;
         END IF;

      end loop;

      --Posiciones de caracteres no permitidos consolidados
      v_pos_lnp := ','||v_pos_lnp;
      v_pos_lnp := '.'||v_pos_lnp;

      --Corrección de los caracteres no permitodo (Ñ)
      v_cont := 0;
      for c1 in car_np loop
       v_pos_lnp2 := c1.pos;

       for c2 in car_np2 loop
        if c2.fila = 1 then

         v_dato_correcto := substr(v_dato, 1, to_number(c2.pos - v_cont) - 1);
        elsif c2.fila = 2 then

         v_dato_correcto := v_dato_correcto || 'N' ||
                            substr(v_dato, to_number(c2.pos - v_cont) + 1);
         v_dato          := v_dato_correcto;
        end if;

       end loop;
       v_cont := v_cont + 1;
      end loop;
      p_dato:= v_dato_correcto;
    end;


--Procedimiento interno para manejo de caracteres especiales2
    procedure lp_pro_car_especiales(p_dato in out varchar2,
                                    p_sucursal in out varchar2,
                                    p_nro_cuenta in out varchar2,
                                    p_relacion in out varchar2,
                                    p_nro_emision in out varchar2,
                                    p_nom_embozado in out varchar2,
                                    p_fec_vencimiento in out varchar2,
                                    p_pin_encriptado in out varchar2,
                                    p_nro_bin in out varchar2)
    is

    begin
        lp_pro_car_especiale(p_dato);


        p_sucursal        := ltrim(rtrim(substr(p_dato,1,3)));                --- sucursal
        p_nro_bin         := ltrim(rtrim(substr(p_dato,4,6)));                --- nro bin
        p_nro_cuenta      := to_char(ltrim(rtrim(substr(p_dato,10,10))));     --- cuenta, tiene 7digitos
        p_nro_cuenta      := LF_VAL_CTA_INFONET(p_nro_cuenta, p_nro_bin);                --- nueva validación para contemplar pines suministro
        p_relacion        := ltrim(rtrim(substr(p_dato,21,2)));               --- relación
        p_nro_emision     := ltrim(rtrim(substr(p_dato,23,2)));               --- nro_emisión
        p_nom_embozado    := ltrim(rtrim(substr(p_dato,25,35)));              --- nombre embozado
        p_fec_vencimiento := ltrim(rtrim(substr(p_dato,60,6)));               --- fecha vencimiento
        p_pin_encriptado  := ltrim(rtrim(substr(p_dato,66,15)));              --- número pin encriptado

    end;

--procedimiento interno de manejo de respuesta (formateo)
    procedure lp_pro_respuesta(p_respuesta clob,
                               p_codigoError varchar2,
                               p_error varchar2,
                               p_descripcionRespuesta varchar2,
                               p_status_code varchar2) is
    PRAGMA AUTONOMOUS_TRANSACTION; --- para que grabe solo esta transaccion
    v_resp_pines_jsonlist typ_jsonlist;
    v_resp_pin_json typ_json;
    v_resp_dato varchar2(500);
    v_resp_err varchar2(4000);

    -- Variables para la inserción en ah_tar_deb_pines
    v_nro_cuenta ah_tar_deb_pines.nro_cuenta%type;
    v_relacion ah_tar_deb_pines.relacion%type;
    v_nro_emision ah_tar_deb_pines.nro_emision%type;
    v_sucursal ah_tar_deb_pines.sucursal%type;
    v_estado ah_tar_deb_pines.estado%type:= 'N'; --agrega estado N (Esperando impresión)
    v_nom_embozado ah_tar_deb_pines.nom_embozado%type;
    --v_nom_embozado_act ah_tar_deb_pines.nom_embozado%type;
    v_fec_vencimiento varchar2(6);--ah_tar_deb_pines.fec_vencimiento%type;
    v_pin_encriptado ah_tar_deb_pines.pin_encriptado%type;

    v_ente ge_entes.descripcion%type;

    v_nro_bin ah_tar_deb_pines.nro_bin%type;

    begin

       if p_error != 'S' then
          --controlamos que el servicio responda con éxito (200)
          if p_status_code = '200' then
             --controlar error de contraseña
             --si no es un array de json
             if DBMS_LOB.SUBSTR(p_respuesta,1,1) = '{' then--significa que es un solo objeto.
                v_resp_pin_json := typ_json(p_respuesta);
                if pag_jex.get_string(v_resp_pin_json, 'result')   is not null then--obtenemos respuesta de result
                    v_con_error:='SI*';
                    v_result:= 'Error al utilizar Servicios WEB Bancard: '||pag_jex.get_string(v_resp_pin_json, 'result');
                end if;
             end if;

             if v_con_error != 'SI*' then

                  --convertimos a jsonlist la respuesta -> estructura json [{"data":"ABCD.."},..N]
                  v_resp_pines_jsonlist := typ_jsonlist(p_respuesta);

                  -- Busca la descripción del Ente.
                     begin
                       select descripcion
                         into v_ente
                         from ge_entes
                        where cod_ente = p_cod_procesadora;
                     exception
                       when others then
                         raise_application_error(-20000,'Error al buscar el Ente '||sqlerrm);
                     end;

                  v_cant_pines := v_resp_pines_jsonlist.count;
                  --recorremos los pines y vamos procesando
                  FOR i IN 1..v_resp_pines_jsonlist.count LOOP
                  v_hay_datos := 'S';

                     v_resp_pin_json := typ_json(v_resp_pines_jsonlist.get(i));
                     v_resp_dato := pag_jex.get_string(v_resp_pin_json, 'data');--obtenemos la línea del archivo de pines

                     -- Procedimento Recupera Campos para la inserción.
                     --Dependiendo del ente Arma los campos.
                     if v_ente = 'BANCARD' then
                        v_sucursal        := ltrim(rtrim(substr(v_resp_dato,1,3)));                --- sucursal
                        v_nro_bin         := to_char(ltrim(rtrim(substr(v_resp_dato,4,6))));
                        v_nro_cuenta      := to_char(ltrim(rtrim(substr(v_resp_dato,10,10))));     --- cuenta, tiene 7digitos
                        --v_nro_cuenta      := FUA_VAL_CTA_INFONET(v_nro_cuenta);()
                        v_nro_cuenta      := LF_VAL_CTA_INFONET(v_nro_cuenta, v_nro_bin);--nueva validación para contemplar pines suministro
                        v_relacion        := ltrim(rtrim(substr(v_resp_dato,21,2)));               --- relación
                        v_nro_emision     := ltrim(rtrim(substr(v_resp_dato,23,2)));               --- nro_emisión
                        v_nom_embozado    := ltrim(rtrim(substr(v_resp_dato,25,35)));              --- nombre embozado

                        /*v_nom_embozado_act:= replace(ltrim(rtrim(substr(v_resp_dato,25,35))),chr(195)||chr(96),chr(209));--control de Ñ
                        if v_nom_embozado != v_nom_embozado_act then
                           v_fec_vencimiento := ltrim(rtrim(substr(v_resp_dato,61,6)));              --- fecha vencimiento
                           v_nom_embozado := v_nom_embozado_act;
                           v_resp_dato :=  replace(v_resp_dato,chr(195)||chr(96),chr(209));
                        else
                           v_fec_vencimiento := ltrim(rtrim(substr(v_resp_dato,60,6)));               --- fecha vencimiento
                        end if;*/
                        v_fec_vencimiento := ltrim(rtrim(substr(v_resp_dato,60,6)));               --- fecha vencimiento
                        v_pin_encriptado  := ltrim(rtrim(substr(v_resp_dato,66,15)));       --- número pin encriptado



                        --controlamos los caraceteres especiales recibidos de bancard
                        if length(v_resp_dato) > 81 and length(v_pin_encriptado)>10 then--registro de pines con caracter no permitido
                          lp_pro_car_especiales(v_resp_dato,
                                                v_sucursal,
                                                v_nro_cuenta,
                                                v_relacion,
                                                v_nro_emision,
                                                v_nom_embozado,
                                                v_fec_vencimiento,
                                                v_pin_encriptado,
                                                v_nro_bin);
                        elsif length(v_resp_dato) > 65 and length(v_pin_encriptado)<10 then--registro de recibos con caracter no permitido
                          lp_pro_car_especiales(v_resp_dato,
                                                  v_sucursal,
                                                  v_nro_cuenta,
                                                  v_relacion,
                                                  v_nro_emision,
                                                  v_nom_embozado,
                                                  v_fec_vencimiento,
                                                  v_pin_encriptado,
                                                  v_nro_bin);
                        end if;
                     elsif v_ente = 'BEPSA' then
                       RAISE_APPLICATION_ERROR(-20000,'Proceso no soportado para otras entidades que no sea BANCARD');
                     end if;

                      Begin
                        INSERT INTO ah_tar_deb_pines
                             ( nro_cuenta, relacion, nro_emision, sucursal, estado,
                               nom_embozado, fec_vencimiento, pin_encriptado, cod_ent_procesadora, registro, nro_pin, nro_bin)
                        VALUES( v_nro_cuenta, v_relacion, v_nro_emision, v_sucursal, v_estado,
                               v_nom_embozado, v_fec_vencimiento, v_pin_encriptado, p_cod_procesadora,v_resp_dato,
                               nvl2(v_pin_encriptado,'0',null),v_nro_bin);
                      exception
                        when dup_val_on_index then
                          --control de reproceso de pines -- DYDMR-3632 - RE - 28/04/2016
                          --Se actualiza si corresponde a una nueva generacion de pin
                             update Ah_Tar_Deb_Pines t
                                set t.registro = v_resp_dato,
                                    t.pin_encriptado = v_pin_encriptado,
                                    t.fec_impresion = null,
                                    t.fec_proceso = null,
                                    t.estado = v_estado
                              where t.nro_cuenta =v_nro_cuenta
                                and t.nro_emision =v_nro_emision
                                and t.relacion = v_relacion
                                and t.cod_ent_procesadora = p_cod_procesadora
                                and nvl(t.nro_bin,v_nro_bin) = v_nro_bin;
                          if sql%notfound then
                             RAISE_APPLICATION_ERROR(-20999,'Error UPDATE FUA_WSI_OBT_ARC_PINES: '||SQLERRM);
                          end if;
                        when others then
                          RAISE_APPLICATION_ERROR(-20000,'Error al insertar en ah_tar_deb_pines : '||SQLERRM);
                      end;


                  END LOOP;

                  commit;--se commitea una vez recibido completo los datos

             end if;
          --errores que no deben continuar con el proceso de envío se marca con (SI*)
          --el servicio Web no ha respondido satisfactoriamente.(diferente a 200 con errores gestionados en el WS)
          elsif p_status_code ='400' then--error de formateo de datos en los parámetros enviados
             v_result:= 'Error al utilizar Servicios WEB Bancard Conector: Parámetros de envío inválidos: '||p_respuesta;
             v_con_error:='SI*';
          elsif p_status_code ='404' then--Servicio no disponible, servidor de bancarconector caido
             v_result:= 'Servicios de conexión a Bancard no disponibles, utilizat operativa contingente';
             v_con_error:='SI*';
          elsif p_status_code in('503','412','500') then--errores soportados en BancardConector
             v_resp_pin_json := typ_json(p_respuesta);
             v_resp_err := pag_jex.get_string(v_resp_pin_json, 'msgError');--obtenemos el mensaje de error

             v_result:= 'Error al utilizar Servicios WEB Bancard Conector: '||v_resp_err;
             v_con_error:='SI*';
          else--otros errores no soportados
             v_result:= 'Error al utilizar Servicios WEB Bancard: '||p_descripcionRespuesta||'-'||p_codigoError||'-'||p_error;
             v_con_error:='SI*';
          end if;

       elsif p_error = 'S' then
          v_con_error:='SI*';
          v_result:= 'Error al utilizar Servicios WEB Bancard Conector: '||p_descripcionRespuesta;
       end if;
    end lp_pro_respuesta;

    --procedimiento interno para el registro de los mensajes
     PROCEDURE LP_REG_OPERACION(p_mensaje IN LONG, p_respuesta IN VARCHAR2) is
       PRAGMA AUTONOMOUS_TRANSACTION; --- para que grabe solo esta transaccion
       v_respuesta ba_log_mensajeria.respuesta%type;
     BEGIN
       v_respuesta := substr(p_respuesta, 1, 4000);
       insert into ba_log_mensajeria
         (mensaje, respuesta)
       values
         (p_mensaje, v_respuesta);
       commit;
     EXCEPTION
       WHEN OTHERS THEN
         raise_application_error(-20000, sqlerrm);
     END;



/*SE obtiene el archivo entero DE pines del servidor FTP bancard*/
BEGIN

      --enviamos al WebSevice
      v_respuesta := FUA_WSI_ENV_POST(v_direccion, g_url_obt_pines, v_metodo);

      -- bitacora de logs
      lp_reg_operacion('/'||v_metodo||'/'||g_url_obt_pines||'/'||v_dir_ftp, substr(v_respuesta.error || ' - ' ||
      v_respuesta.codigoError ||' - ' || v_respuesta.respuesta, 1, 4000));
      --procesamos la respuesta
      lp_pro_respuesta(v_respuesta.respuesta,
                       v_respuesta.codigoError,
                       v_respuesta.error,
                       v_respuesta.descripcionRespuesta,
                       v_respuesta.status_code);

   if v_con_error = 'SI*' then
      ROLLBACK;
      return v_result;
   elsif v_con_error = 'NO' then
      commit;
      return 'Proceso finalizado, se recibieron ('||v_cant_pines||') pines encriptados exitosamente!';
   end if;


EXCEPTION
   WHEN OTHERS THEN
      ROLLBACK;

      RAISE_APPLICATION_ERROR(-20000, '*Error al obtener pines encritpados : '||SQLERRM);

END FUA_WSI_OBT_ARC_PINES;
/

