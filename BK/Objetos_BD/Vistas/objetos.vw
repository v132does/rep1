create or replace force view it.objetos as
select
t.owner Propietario,--nombre del propietario
T.OBJECT_NAME nombre_objeto,--nombre del objeto
t.object_type tipo_objeto, -- nombre del tipo de objeto
t.created fecha_creacion, -- fecha de creación del objeto
t.LAST_DDL_TIME ultima_modificacion --fecha de la modificación
from sys.all_objects t where t.owner like 'IT' order by t.last_ddl_time desc
;

