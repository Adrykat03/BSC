using BSC.Domain.Entities;
using MongoDB.Bson;
using MongoDB.Bson.Serialization;
using MongoDB.Bson.Serialization.IdGenerators;
using MongoDB.Bson.Serialization.Serializers;

namespace BSC.Infrastructure.Persistence;

public static class MongoDbMappings
{
    public static void Configure()
    {
        if (!BsonClassMap.IsClassMapRegistered(typeof(Colaborador)))
        {
            BsonClassMap.RegisterClassMap<Colaborador>(cm =>
            {
                cm.AutoMap();
                cm.MapIdMember(c => c.Id)
                    .SetIdGenerator(StringObjectIdGenerator.Instance)
                    .SetSerializer(new StringSerializer(BsonType.ObjectId));
            });
        }

        // AlertaEstadoHistorial ya define [BsonId] + [BsonRepresentation(BsonType.ObjectId)]
        // mediante atributos, igual que TaskItem; no necesita ClassMap explicito.
    }
}
