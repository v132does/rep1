CREATE OR REPLACE PACKAGE IT.PAL_VAR IS

    -- Autor   : XPY9515
    -- Creado  : 05/08/2013 08:54:21 a.m.
    -- Objetivo: Controlar Límites de Valor de Riesgo (Límite VaR)
    
     /* Declarar un Record Type */
   TYPE RecType IS RECORD( valor   NUMBER
                          );
   
   /* Declarar un Table Type sobre el Record Type */
   TYPE TblType IS TABLE OF RecType
                         INDEX BY PLS_INTEGER;

   /* Declarar un Table Type sobre el Table Type (2da tabla o Matriz)*/
   TYPE TblOfTblType IS TABLE OF TblType
                           INDEX BY PLS_INTEGER;
                           
    -- Public function and procedure declarations
    PROCEDURE pr_obt_dif_pos_cambio (
        p_sec IN lc_pos_cambios_tmp.secuencia%TYPE,
        p_fecha IN DATE,
        p_oficina lc_pos_cambios_tmp.cod_oficina%TYPE DEFAULT NULL
    );
    
    PROCEDURE pr_cal_pos_cambio(
        p_fecha IN DATE DEFAULT NULL,
        p_oficina IN lc_tot_pos_cambios.cod_oficina%TYPE DEFAULT NULL,
        p_moneda IN lc_tot_pos_cambios.cod_moneda%TYPE DEFAULT NULL,
        p_monto IN lc_tot_pos_cambios.compra_spot_me%TYPE DEFAULT 0,
        p_cotizacion IN lc_tot_pos_cambios.cotizacion%TYPE DEFAULT 0,
        p_modalidad IN ge_movimientos.cod_mad_padre%TYPE DEFAULT NULL,
        p_segmento IN lc_pos_cambios_tmp.segmento%TYPE DEFAULT NULL,
        p_cod_error IN OUT NUMBER,
        p_mensaje IN OUT VARCHAR2
    );
    
    PROCEDURE pr_con_pos_cambio (
        p_usuario IN ge_aut_pedidos.cod_usuario%TYPE,
        p_oficina IN ge_movimientos.cod_oficina%TYPE,
        p_moneda IN ge_movimientos.cod_moneda%TYPE,
        p_monto IN ge_movimientos.monto%TYPE,
        p_cotizacion IN ge_movimientos.cotizacion%TYPE,
        p_tip_oper IN lc_tip_operaciones.descripcion%TYPE,
        p_modalidad IN ge_movimientos.cod_mad_padre%TYPE,
        p_segmento IN lc_pos_cambios_tmp.segmento%TYPE,
        p_fecha IN ge_movimientos.fecha%TYPE,
        p_hora IN ge_movimientos.hora%TYPE,
        p_home_bank IN VARCHAR2 DEFAULT 'N',
        p_confirma IN VARCHAR2,
        p_estado IN OUT ge_movimientos.estado%TYPE,
        p_cod_error IN OUT NUMBER,
        p_mensaje IN OUT VARCHAR2
    );
    
    PROCEDURE pr_wrap_con_pos_cambio (
        p_usuario IN ge_aut_pedidos.cod_usuario%TYPE,
        p_oficina IN ge_movimientos.cod_oficina%TYPE,
        p_moneda IN ge_movimientos.cod_moneda%TYPE,
        p_monto IN ge_movimientos.monto%TYPE,
        p_cotizacion IN ge_movimientos.cotizacion%TYPE,
        p_tip_oper IN lc_tip_operaciones.descripcion%TYPE,
        p_modalidad IN ge_movimientos.cod_mad_padre%TYPE,
        p_segmento IN lc_pos_cambios_tmp.segmento%TYPE,
        p_fecha IN ge_movimientos.fecha%TYPE,
        p_hora IN ge_movimientos.hora%TYPE,
        p_home_bank IN VARCHAR2 DEFAULT 'N',
        p_confirma IN VARCHAR2,
        p_estado IN OUT ge_movimientos.estado%TYPE,
        p_cod_error IN OUT NUMBER,
        p_mensaje IN OUT VARCHAR2
    );
    
    PROCEDURE pr_wrap_cal_pos_cambio;

-- Operaciones con Matrices --   

    /* Inicializar Matriz (m*n) */
    function fu_ini_matriz( m integer, -- Número de Filas
                            n integer  -- Número de Columnas
                            ) return TblOfTblType; 
                            
    /* Multiplicar matrices -- A(m*p)*B(p*N) -- Resultado = Matriz R(m*n) */
    function fu_mul_matrices( m    integer, -- Número de Filas de A
                              p    integer, -- Número de Columnas de A = Número de Filas de B
                              n    integer, -- Número de Columnas de B
                              matA TblOfTblType, -- Matriz A
                              matB TblOfTblType -- Matriz B  
                             ) return TblOfTblType;
    
    /* Invertir Matriz (m*n) */
    function fu_inv_matriz( m      integer,  -- Número de Filas
                            n      integer,  -- Número de Columnas
                            mat    TblOfTblType -- Matriz a invertir
                           ) return TblOfTblType;
    
                                                       
    
--

-- Cálculo del VaR Global --   
  
    PROCEDURE pr_cal_var( p_fecha         IN DATE,
                          p_oficina       IN lc_tot_pos_cambios.cod_oficina%TYPE,
                          p_lim_factor    IN NUMBER,
                          p_volatilidad   IN OUT lc_tot_pos_cam_global.volatilidad%type, 
                          p_valor_riesgo  IN OUT lc_tot_pos_cam_global.valor_riesgo%type,  
                          p_pos_neta_pyg  IN OUT lc_tot_pos_cam_global.pos_neta_pyg%type, 
                          p_limite_var    IN OUT lc_tot_pos_cam_global.limite_var%type );
                                                 
    PROCEDURE pr_cal_var_global( 
      p_fecha     IN DATE DEFAULT NULL,
      p_oficina   IN lc_tot_pos_cambios.cod_oficina%TYPE DEFAULT NULL,
      p_cod_error IN OUT NUMBER,
      p_mensaje   IN OUT VARCHAR2
      );

END PAL_VAR;
/

