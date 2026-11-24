CREATE OR REPLACE PROCEDURE IT.prw_imp_claves(p_tip_proceso   IN VARCHAR2,
                                           p_tip_clave     IN VARCHAR2,
                                           p_tip_impresion IN VARCHAR2,
                                           p_cod_persona   IN VARCHAR2,
                                           p_per_vinculada IN VARCHAR2,
                                           p_clave         IN VARCHAR2,
                                           p_cadena        OUT VARCHAR2,
                                           p_ok            OUT VARCHAR2) IS
   --P_Tip_Clave (Acceso ó Transaccional)
   --P_Tip_Impresion (Impresión ó Reimpresión
   v_actualizo BOOLEAN;
   ---
   -- Obtiene Cadena para Impresión
   ---
   PROCEDURE pr_obt_cadena IS
     v_cod_dir_tarjeta ta_tarjetas.referencia%type;
     v_dir_tarjeta     varchar2(120);
   BEGIN
     /* Se busca inicialmente la dirección de envio de extracto de alguna tarjeta del cliente
        ya que esta es la mas utilizada para los envios de documentos */
     BEGIN
       select b.referencia
         into v_cod_dir_tarjeta
         from ta_tarjetas b
        where b.vigente = 'S'
          and b.tip_envio = 'D'
          and b.nro_cuenta in (select a.nro_cuenta 
                                 from ge_cta_clientes a
                                where a.cod_persona = p_cod_persona
                                  and a.cod_modulo = 5)
          and rownum <=1;
     EXCEPTION
       when no_data_found then
         v_cod_dir_tarjeta := null;
       when others then
         v_cod_dir_tarjeta := null;
     END;
     if v_cod_dir_tarjeta is not null then
       begin
         select direccion||decode(numero,null,'',' '||numero)
           into v_dir_tarjeta
           from ba_direcciones a 
          where a.cod_persona = p_cod_persona
            and a.cod_direccion = v_cod_dir_tarjeta;
       exception
         when no_data_found then
         v_dir_tarjeta := null;
         when others then
         v_dir_tarjeta := null;
       end;
     end if;
   BEGIN
       SELECT fue_obt_nom_persona(bc.cod_per_vinculada) || '::' ||
              bc.cod_persona || '::' || 
              fue_obt_nom_persona(bc.cod_persona) || '::' ||
              fue_obt_nro_doc_persona(bc.cod_persona) || '::' ||
              nvl(v_dir_tarjeta,fue_obt_dir_principa(bc.cod_persona)) || '::' ||
              fue_obt_tel_principa(bc.cod_persona) || '::' || 
              decode(p_tip_clave, 'A', 'CLAVE DIGITAL'/*||fug_obt_pardinamico('NOM_BANCO')*/, 'CLAVE TRANSACCIONAL') || '::' ||
              p_clave || '::' || 
              to_char(pag_cal.fu_obt_fec_actual(1), 'DD/MM/YYYY') || ' :: ' ||
              paw_bce.fu_obt_nro_seguridad(bc.cod_persona, bc.cod_per_vinculada, p_tip_clave) || '::' ||
              fue_obt_des_oficina(fug_obt_ofi_usuario(USER)) || '::' || USER || '::' ||nro_lote|| '::' ||
              cod_persona|| '::' ||
              decode(FUE_OBT_COD_ENT_PER(BC.COD_PERSONA),null,' ',fue_obt_nom_ente(FUE_OBT_COD_ENT_PER(BC.COD_PERSONA)))|| '::' ||
              decode(FUE_OBT_COD_ENT_PER(BC.COD_PERSONA),null,' ',fue_obt_dir_principa(fue_obt_per_ente(FUE_OBT_COD_ENT_PER(BC.COD_PERSONA))))
              /* Se vuelve a agregar el cod_persona para utilizar en la generación de código de barras
                             ya que se toma el último campo de la cadena.
                          */
         INTO p_cadena
         FROM bw_ope_claves bc
        WHERE bc.est_clave = 'N'
          AND bc.cod_persona = p_cod_persona
          AND bc.tip_clave = p_tip_clave
          AND (
                (p_per_vinculada IS NULL AND bc.cod_per_vinculada IS NULL) OR 
                (p_per_vinculada IS NOT NULL AND bc.cod_per_vinculada = p_per_vinculada)
              )
          AND bc.clave IS NOT NULL;       
     EXCEPTION
        WHEN OTHERS THEN
           raise_application_error(-20000, 'en pr_obt_cadena ' || SQLERRM);
     END;
   END;

   ---
   -- Actualiza estado de hoja de seguridad
   ---
   PROCEDURE pr_act_documentos IS
      v_nro_hoj_seguridad VARCHAR2(6);
   BEGIN
      BEGIN
         v_nro_hoj_seguridad := paw_bce.fu_obt_nro_seguridad(p_cod_persona,
                                                             p_per_vinculada,
                                                             p_tip_clave);
         pag_doc.pr_act_estado(1, fug_obt_ofi_usuario(USER), v_nro_hoj_seguridad, 'I');
      EXCEPTION
         WHEN OTHERS THEN
            raise_application_error(-20000, 'en pr_act_documentos ' || SQLERRM);
      END;
   END;
   
   ---
   -- Actualiza cantidad de impresiones
   ---
   PROCEDURE pr_act_can_impresion(p_cod_persona in bw_ope_claves.cod_persona%type) IS
      v_can_impresion number;
   BEGIN
      BEGIN
         select nvl(can_impresion, 0) 
           into v_can_impresion
          from bw_ope_claves
          where cod_persona = p_cod_persona
            and tip_clave = 'A'
            and est_clave = 'N'; 
            v_can_impresion := v_can_impresion + 1;
      EXCEPTION
         WHEN NO_DATA_FOUND THEN
            v_can_impresion := 1;
         WHEN OTHERS THEN
            raise_application_error(-20000, 'en pr_act_documentos ' || SQLERRM);
      END;
      update bw_ope_claves
         set can_impresion = v_can_impresion
       Where cod_persona = p_cod_persona
         and tip_clave = 'A'
         and est_clave = 'N';
   END;

   ---
   -- Inserta Acción
   ---
   PROCEDURE pr_ins_accion IS
   BEGIN
      INSERT INTO bw_cla_acciones
         (cod_persona, cod_per_vinculada, accion, tip_clave)
      VALUES
         (p_cod_persona, p_per_vinculada, p_tip_impresion, p_tip_clave);
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000, 'en pr_ins_accion ' || SQLERRM);
   END;

   ---
   -- Principal
   ---
BEGIN
   -- Generación
   IF p_tip_proceso = 'G' THEN
      pr_obt_cadena;
      -- Actualización
   ELSIF p_tip_proceso = 'A' THEN
      pr_act_documentos;
      pr_ins_accion;
      -- Actualiza estado de clave
      v_actualizo := paw_bce.fu_act_est_clave(p_cod_persona, p_per_vinculada, p_tip_clave, 'I');
      IF v_actualizo THEN
         p_ok := 'OK';
      ELSE
         p_ok := 'ERR';
      END IF;
   ELSIF p_tip_proceso = 'M' THEN
       pr_act_can_impresion(p_cod_persona);
       pr_ins_accion;
        -- Actualiza estado de clave
        v_actualizo := paw_bce.fu_act_est_clave(p_cod_persona, p_per_vinculada, p_tip_clave, 'A');
        IF v_actualizo THEN
           p_ok := 'OK';
        ELSE
           p_ok := 'ERR';
        END IF;
   END IF;
EXCEPTION
   WHEN OTHERS THEN
      IF SQLCODE <= -20000 THEN
         RAISE;
      ELSE
         raise_application_error(-20000, 'en prw_imp_claves ' || SQLERRM);
      END IF;
END;
/

