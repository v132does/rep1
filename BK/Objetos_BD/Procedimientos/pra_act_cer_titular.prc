CREATE OR REPLACE PROCEDURE IT.PRA_ACT_CER_TITULAR
(P_NRO_CUENTA IN AH_CTA_CERTIFICADOS.NRO_CUENTA%TYPE,
 P_COD_CLIENTE IN GE_CTA_CLIENTES.COD_PERSONA%TYPE,
 P_MENSAJE OUT VARCHAR2
)
IS   
   /*---------------------------------------------
   ISSUE: SDCAMTICDA-1 
   CAMBIO DE TITULARIDAD DE CDA
   AUTOR: Adrian Lesme
   ----------------------------------------------*/
   v_cod_per_actual ge_cta_clientes.cod_persona%type;
   v_usu_pro_actual ah_cta_certificados.cod_usu_promotor%type;  
   v_usu_pro_nuevo  ah_cta_certificados.cod_usu_promotor%type;
   v_ofi_cli_actual ge_cta_clientes.cod_oficina%type;
   v_ofi_cli_nuevo  ge_cta_clientes.cod_oficina%type;
   v_monto          ah_cta_certificados.capital%type;
   v_perfil         varchar2(1000);   

   -- funcion que retorna S/N si el CDA tiene o no credito automatico en cuenta
   FUNCTION lf_exi_cre_automatico
   (
      P_NRO_CTA_CDA AH_CTA_CERTIFICADOS.NRO_CUENTA%TYPE
   ) RETURN VARCHAR2
   IS
      v_cre_aut_existe  VARCHAR2(1) := 'N';
   BEGIN
      BEGIN
         SELECT 'S'
         INTO v_cre_aut_existe
         FROM AH_CTA_CERTIFICADOS 
         WHERE CRE_AUTOMATICO = 'S'
            AND NRO_CTA_CREDITO IS NOT NULL
            AND NRO_CUENTA = P_NRO_CTA_CDA; 
      EXCEPTION
         WHEN no_data_found THEN
            v_cre_aut_existe := 'N';
         WHEN OTHERS THEN
            raise_application_error(-20000, 'Error al verificar si cuenta con Credito Automatico. '||SQLERRM);   
      END;
      
      RETURN v_cre_aut_existe;
   END;
   
   -- funcion que retorna S/N si el CDA se encuentra o no pignorado
   FUNCTION lf_exi_gar_pignoracion
   ( 
      P_NRO_CTA_CDA AH_CTA_CERTIFICADOS.NRO_CUENTA%TYPE
   ) RETURN VARCHAR2
   IS
      v_existe VARCHAR2(1) := 'N';
   BEGIN
      BEGIN
         SELECT 'S'
         INTO v_existe
         FROM PR_GAR_CASH A, PR_GARANTIAS B
         WHERE A.NRO_GARANTIA = B.NRO_GARANTIA  
            AND A.NRO_CTA_REFERENCIA = P_NRO_CTA_CDA
            AND B.ESTADO IN ('I','C','A'); -- I (Ingresada) C (Confirmada) A (Aprobada)
      
      EXCEPTION   
         WHEN no_data_found THEN
            v_existe := 'N';
         WHEN OTHERS THEN
            raise_application_error(-20000, 'Error al verificar si cuenta con Credito Automatico. '||SQLERRM);
       END;
       
       RETURN v_existe;
   END;  
   
   -- funcion que retorna el capital del CDA
   FUNCTION lf_obt_capital_cda
   ( 
      P_NRO_CTA_CDA AH_CTA_CERTIFICADOS.NRO_CUENTA%TYPE
   ) RETURN VARCHAR2
   IS
      v_capital AH_CTA_CERTIFICADOS.CAPITAL%TYPE := 0;
   BEGIN       
      SELECT NVL(CAPITAL,0)
      INTO v_capital
      FROM AH_CTA_CERTIFICADOS
      WHERE NRO_CUENTA = P_NRO_CTA_CDA;
      
      RETURN v_capital;
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000, 'Error al obtener el capital del Certificado. '||SQLERRM);
   END;
   
   -- funcion que retorna S/N si la cuenta se encuentra activa o no
   FUNCTION lf_val_est_activo_cda
   (
      P_NRO_CTA_CDA AH_CTA_CERTIFICADOS.NRO_CUENTA%TYPE
   ) RETURN VARCHAR2
   IS
      v_est_activo  VARCHAR2(1) := 'N';
   BEGIN
      BEGIN
         SELECT 'S'
         INTO v_est_activo
         FROM AH_CTA_CERTIFICADOS 
         WHERE NRO_CUENTA = P_NRO_CUENTA
             AND ESTADO IN ('N', 'V'); 
      EXCEPTION
         WHEN no_data_found THEN
            v_est_activo := 'N';
         WHEN OTHERS THEN
            raise_application_error(-20000, 'Error al verificar el estado de la cuenta. '||SQLERRM);   
      END;
      
      RETURN v_est_activo;
   END;     
   
   -- Funcion que retorna S/N si la persona juridica es un banco local con estado activo
   FUNCTION lf_es_banco
   (
      P_COD_PERSONA GE_BANCOS.COD_PERSONA%TYPE    
   ) RETURN VARCHAR2
   IS 
      v_es_banco VARCHAR2(1);
   BEGIN
      BEGIN
         SELECT 'S'
         INTO v_es_banco
         FROM GE_BANCOS 
         WHERE COD_PERSONA = P_COD_PERSONA
           AND UBICACION = 'L'
           AND ESTADO = 'A';           
      EXCEPTION
         WHEN no_data_found THEN
            v_es_banco := 'N';
         WHEN others THEN
            raise_application_error(-20000, 'Error al verificar si la PJ es Banco. '||SQLERRM);
      END;
      RETURN v_es_banco;
   END;       
BEGIN

   BEGIN pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; END;
   
   -- Valida que el estado del Cerfificado sea Normal o Vencida para proceder al cambio
   IF lf_val_est_activo_cda(P_NRO_CUENTA) = 'S' THEN
      -- Validar que el certificado no tenga configurado credito automatico
      IF lf_exi_cre_automatico(P_NRO_CUENTA) = 'N' THEN
         -- Validar que el certificado no este pignorado en alguna operacion
         IF lf_exi_gar_pignoracion(P_NRO_CUENTA) = 'N' THEN     
            -- Valido que el nuevo titular no sea una entidad bancaria, si lo es, no debe verificar el perfil del cliente
            IF lf_es_banco(P_COD_CLIENTE) = 'S' THEN
               v_perfil := 'S';
            ELSE 
               -- verifico el perfil del cliente, se excluye entidades bancarias
               v_perfil := fug_obt_per_cliente(P_COD_CLIENTE, 3);         
            END IF;            
            IF v_perfil = 'S' THEN
                 BEGIN
                    SELECT COD_PERSONA
                    into v_cod_per_actual
                    FROM GE_CTA_CLIENTES
                    WHERE NRO_CUENTA = P_NRO_CUENTA
                       AND RELACION = 'P';
                 EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                       raise_application_error(-20000, 'La cuenta no tiene titular.'||SQLERRM);
                    WHEN OTHERS THEN
                       raise_application_error(-20000, 'Error al obtener el titular de la cuenta.'||SQLERRM);
                 END;
                 
                 IF v_cod_per_actual <> P_COD_CLIENTE THEN                       
                     BEGIN              
                        -- Obtener la oficina del cliente actual
                        v_ofi_cli_actual := fug_obt_ofi_oficial(v_cod_per_actual);
                        -- Obtener la oficina del cliente nuevo
                        v_ofi_cli_nuevo := fug_obt_ofi_oficial(P_COD_CLIENTE);                                      
                        -- Se elimina todas la relaciones de la cuenta que no sea el principal
                        DELETE GE_CTA_CLIENTES WHERE NRO_CUENTA = P_NRO_CUENTA AND RELACION <> 'P'; 
                        -- Si la Oficina es diferenete actualizo la oficina                         
                        IF v_ofi_cli_actual <> v_ofi_cli_nuevo THEN                        
                           -- Actualizo la oficina de la relacion de la cuenta 
                           UPDATE GE_CTA_CLIENTES 
                           SET COD_PERSONA = P_COD_CLIENTE,
                              COD_OFICINA = v_ofi_cli_nuevo
                           WHERE NRO_CUENTA = P_NRO_CUENTA
                              AND RELACION = 'P';
                           -- Actualizo la oficina de la cuenta   
                           UPDATE GE_CUENTAS SET COD_OFICINA = v_ofi_cli_nuevo WHERE NRO_CUENTA = P_NRO_CUENTA;
                           -- Actualizo el CDA
                           BEGIN
                              UPDATE AH_CTA_CERTIFICADOS 
                              SET COD_OFICINA = v_ofi_cli_nuevo
                                 WHERE NRO_CUENTA = P_NRO_CUENTA;                 
                           EXCEPTION
                              WHEN OTHERS THEN
                                 raise_application_error(-20000, 'Error al actualizar la oficina del Certificado'||SQLERRM);
                           END;
                        ELSE
                           UPDATE GE_CTA_CLIENTES 
                           SET COD_PERSONA = P_COD_CLIENTE
                           WHERE NRO_CUENTA = P_NRO_CUENTA
                              AND RELACION = 'P';
                        END IF;                 
                        --
                        V_MONTO := lf_obt_capital_cda(P_NRO_CUENTA);  
                        -- Registrar el cambio en el Historico
                        INSERT INTO AH_CER_TITULARES VALUES (P_NRO_CUENTA,
                                                                    v_cod_per_actual,
                                                                    P_COD_CLIENTE,
                                                                    SYSDATE,
                                                                    fug_obt_cod_usu_oficial(v_cod_per_actual),
                                                                    fug_obt_cod_usu_oficial(p_cod_cliente),
                                                                    v_ofi_cli_actual,
                                                                    v_ofi_cli_nuevo,
                                                                    v_monto,
                                                                    user,
                                                                    sysdate,
                                                                    user,
                                                                    sysdate);
                        
                        COMMIT;
                        P_MENSAJE := 'NOTA: Cambio del Titular de la Cuenta exitosa.';          
                     EXCEPTION
                        WHEN OTHERS THEN
                           P_MENSAJE := 'ERROR. Ocurrio un Error.';
                           raise_application_error(-20000, 'Error al actualizar la oficina del Certificado'||SQLERRM);
                     END;           
                 ELSE
                     P_MENSAJE := 'ATENCION: El Titular del CDA y el Nuevo Titular no deben coincidir.';       
                 END IF;
            ELSE
               P_MENSAJE := 'ATENCION: '||v_perfil;
            END IF;
         ELSE
            P_MENSAJE := 'ATENCION: El CDA esta como garantia (pignoracion) de alguna operacion. No es posible realizar el cambio de Titular.';
            --raise_application_error(-20000,sqlerrm);
         END IF;
      ELSE
         P_MENSAJE := 'ATENCION: No es posible realizar el cambio, el CDA posee credito de intereses en cuenta.';
         --raise_application_error(-20000,sqlerrm);
      END IF;      
   -- Validar si el gestor es de la misma oficina o sino actualizar la relaci?n de cta cliente y cta
   ELSE
      P_MENSAJE := 'ATENCION: No se pudo realizar el cambio de Titular, la cuenta se encuentra bloqueada o totalmente pagada.';
   END IF;
   -- Actualizar el certificado si la oficina es diferente  
EXCEPTION
   WHEN OTHERS THEN
       raise_application_error(-20019, SQLERRM);
END;
/

